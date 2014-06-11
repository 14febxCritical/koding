class ComputeController extends KDController

  @providers = KD.config.providers

  constructor:->
    super

    { mainController, kontrol } = KD.singletons

    mainController.ready =>

      @kloud         = kontrol.getKite
        name         : "kloud"
        environment  : KD.config.environment

      @eventListener = new ComputeEventListener

      @on "machineBuildCompleted", => delete @stacks


  fetchStacks: (callback = noop)->

    if @stacks
      callback null, @stacks
      info "Stacks returned from cache."
      return

    KD.remote.api.JStack.some {}, (err, stacks = [])=>
      return callback err  if err?
      callback null, @stacks = stacks


  fetchMachines: (callback)->

    @fetchStacks (err, stacks)->
      return callback err  if err?

      machines = []
      stacks.forEach (stack)->
        stack.machines.forEach (machine)->
          machines.push new Machine { machine }

      callback null, machines


  credentialsFor: (provider, callback)->
    KD.remote.api.JCredential.some { provider }, callback

  fetchAvailable: (options, callback)->
    KD.remote.api.ComputeProvider.fetchAvailable options, callback

  fetchExisting: (options, callback)->
    KD.remote.api.ComputeProvider.fetchExisting options, callback

  create: (options, callback)->
    KD.remote.api.ComputeProvider.create options, callback

  createDefaultStack: ->

    KD.remote.api.ComputeProvider.createGroupStack (err, stack)=>
      return if KD.showError err

      delete @stacks
      @emit "renderStacks"


  destroy: (machine)->

    ComputeController.UI.askFor 'destroy', machine, =>

      @eventListener.triggerState machine,
        status      : Machine.State.Terminating
        percentage  : 0

      @kloud.destroy { machineId: machine._id }

      .then (res)=>

        @eventListener.addListener 'destroy', machine._id
        log "destroy res:", res

      .catch (err)=>

        @eventListener.revertToPreviousState machine
        warn "destroy err:", err


  build: (machine)->

    @eventListener.triggerState machine,
      status      : Machine.State.Building
      percentage  : 0

    @kloud.build { machineId: machine._id }

    .then (res)=>

      @eventListener.addListener 'build', machine._id
      log "build res:", res

    .catch (err)=>

      @eventListener.revertToPreviousState machine
      warn "build err:", err


  start: (machine)->

    @eventListener.triggerState machine,
      status      : Machine.State.Starting
      percentage  : 0

    @kloud.start { machineId: machine._id }

    .then (res)=>

      @eventListener.addListener 'start', machine._id
      log "start res:", res

    .catch (err)=>

      @eventListener.revertToPreviousState machine
      warn "start err:", err


  stop: (machine)->

    @eventListener.triggerState machine,
      status      : Machine.State.Stopping
      percentage  : 0

    @kloud.stop { machineId: machine._id }

    .then (res)=>

      @eventListener.addListener 'stop', machine._id
      log "stop res:", res

    .catch (err)=>

      @eventListener.revertToPreviousState machine
      warn "stop err:", err


  info: (machine)->

    stateEvent = StateEventMap[machine.status.state]

    if stateEvent
      @eventListener.addListener stateEvent, machine._id
      return Promise.resolve()

    @eventListener.triggerState machine,
      status      : machine.status.state
      percentage  : 0

    @kloud.info { machineId: machine._id }

    .then (response)=>

      log "info response:", response
      @eventListener.triggerState machine,
        status      : response.state
        percentage  : 100

    .catch (err)=>

      @eventListener.revertToPreviousState machine
      warn "info err:", err


  StateEventMap =

    Stopping    : "stop"
    Building    : "build"
    Starting    : "start"
    Rebooting   : "restart"
    Terminating : "destroy"
