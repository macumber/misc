# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

# start the measure
class FurnaceOptions < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "Furnace Options"
  end

  # human readable description
  def description
    return ""
  end

  # human readable description of modeling approach
  def modeler_description
    return ""
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new
    
    chs = OpenStudio::StringVector.new
    chs << "Baseline"
    chs << "80% Two Stage Variable Speed"
    chs << "96% Single Stage Constant Speed"
    chs << "96% Two Stage Variable Speed"
    option_name = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('option_name', chs, true)
    option_name.setDefaultValue("Baseline")
    args << option_name

    chs = OpenStudio::StringVector.new
    chs << "3 Ton"
    chs << "4 Ton"
    chs << "5 Ton"
    blower_size = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('blower_size', chs, true)
    blower_size.setDefaultValue("3 Ton")
    args << blower_size
    
    chs = OpenStudio::StringVector.new
    chs << "70,000 Btu/h"
    chs << "90,000 Btu/h"
    chs << "110,000 Btu/h"
    furnace_size = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('furnace_size', chs, true)
    furnace_size.setDefaultValue("110,000 Btu/h")
    args << furnace_size
    
    cost = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('cost', true)
    cost.setDefaultValue(0.0)
    args << cost

    return args
  end
  
  def makeConstantFans(efficiency, flow_rate, model)
    model.getFanConstantVolumes.each do |fan|
      fan.setFanEfficiency(efficiency)
      fan.setMaximumFlowRate(flow_rate)
    end
  end
  
  def makeVariableFans(efficiency, flow_rate, model)
    model.getFanConstantVolumes.each do |fan|
      outletModelObject = fan.outletModelObject
      if !outletModelObject.empty?
        if !outletModelObject.get.to_Node.empty?
          new_fan = OpenStudio::Model::FanVariableVolume.new(model)
          new_fan.setFanEfficiency(efficiency)
          new_fan.setMaximumFlowRate(flow_rate)
          new_fan.addToNode(outletModelObject.get.to_Node.get)
          fan.remove
        end
      end
    end
  end
  
  def makeSingleStage(efficiency, capacity, model)
    model.getCoilHeatingGass.each do |coil|
      coil.setGasBurnerEfficiency(efficiency)
      coil.setNominalCapacity(capacity)
    end
  end
  
  def makeMultiStage(efficiency, capacity, model)
    model.getCoilHeatingGass.each do |coil|
      outletModelObject = coil.outletModelObject
      if !outletModelObject.empty?
        if !outletModelObject.get.to_Node.empty?
          new_coil = OpenStudio::Model::CoilHeatingGasMultiStage.new(model)
          
          stage1 = OpenStudio::Model::CoilHeatingGasMultiStageStageData.new(model)
          stage1.setGasBurnerEfficiency(efficiency)
          stage1.setNominalCapacity(0.5*capacity)
          new_coil.addStage(stage1)
          
          stage2 = OpenStudio::Model::CoilHeatingGasMultiStageStageData.new(model)
          stage2.setGasBurnerEfficiency(efficiency)
          stage2.setNominalCapacity(capacity)
          new_coil.addStage(stage2)
          
          new_coil.addToNode(outletModelObject.get.to_Node.get)
          coil.remove
        end
      end
    end
  end
  
  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # assign the user inputs to variables
    option_name = runner.getStringArgumentValue("option_name", user_arguments)
    blower_size = runner.getStringArgumentValue("blower_size", user_arguments)
    furnace_size = runner.getStringArgumentValue("furnace_size", user_arguments)
    cost = runner.getDoubleArgumentValue("cost", user_arguments)
    
    building = model.getBuilding
    OpenStudio::Model::LifeCycleCost.createLifeCycleCost("Furnace", building, cost, "CostPerEach", "HVAC")
    
    # coiling is SEER 14 ~ COP of 3.7
    # coiling has 3 ton capacity ~ 10550 W
    
    fan_efficiency = 0.8
    
    flow_rate = 0
    if blower_size == "3 Ton"
      cfm = 0.075*1400
      flow_rate = 0.000471947443*cfm
    elsif blower_size == "4 Ton"
      cfm = 1400
      flow_rate = 0.000471947443*cfm
    elsif blower_size == "5 Ton"
      cfm = 1.25*1400
      flow_rate = 0.000471947443*cfm
    end

    furn_capacity = 0
    if furnace_size == "70,000 Btu/h"
      furn_capacity = 0.29307107*70000
    elsif furnace_size == "90,000 Btu/h"
      furn_capacity = 0.29307107*90000
    elsif furnace_size == "110,000 Btu/h"
      furn_capacity = 0.29307107*100000
    end
    
    if option_name == "Baseline"
    
      furn_efficiency = 0.8
      makeConstantFans(fan_efficiency, flow_rate, model)
      makeSingleStage(furn_efficiency, furn_capacity, model)
      
    elsif option_name == "80% Two Stage Variable Speed"
    
      furn_efficiency = 0.8
      makeVariableFans(fan_efficiency, flow_rate, model)
      makeMultiStage(furn_efficiency, furn_capacity, model)
      
    elsif option_name == "96% Single Stage Constant Speed"
      
      furn_efficiency = 0.96
      makeConstantFans(fan_efficiency, flow_rate, model)
      makeSingleStage(furn_efficiency, furn_capacity, model)
        
    elsif option_name == "96% Two Stage Variable Speed"
    
      furn_efficiency = 0.96
      makeVariableFans(fan_efficiency, flow_rate, model)
      makeMultiStage(furn_efficiency, furn_capacity, model)
      
    end

    return true

  end
  
end

# register the measure to be used by the application
FurnaceOptions.new.registerWithApplication
