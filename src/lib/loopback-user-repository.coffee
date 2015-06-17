
LoopbackRepository = require './loopback-repository'

###*
@class LoopbackUserRepository
@extends LoopbackRepository
###
class LoopbackUserRepository extends LoopbackRepository
    ###*
    constructor

    @constructor
    @param {Object}  [options]
    @param {String}  [options.sessionId] Session ID
    @param {Boolean} [options.debug] shows debug log if true
    ###
    constructor: (options = {}) ->
        super(options)
        modelName = @constructor.modelName
        @client = @getFacade().lbPromised.createUserClient(modelName, options)



    ###*
    get sessionId from account information (email/password)

    @param {String} email
    @param {String} password
    @param {Boolean|String} [include] fetch related model if true. fetch submodels if 'include'. fetch submodels recursively if 'recursive'
    @return {Promise(Object)}
    ###
    login: (email, password, include) ->
        includeUser = include?
        @client.login({email: email, password: password}, if includeUser then 'user' else null).then (response) =>
            accessToken = response.id
            userId = if includeUser then response.user.id else response.userId

            ret =
                sessionId: accessToken + '/' + userId
                ttl: response.ttl

            if includeUser
                model = @factory.createFromObject(response.user)
                ret[@constructor.modelName] = model

                if include is 'include'

                    facade = @getFacade()
                    oldSessionId = facade.sessionId
                    facade.setSessionId ret.sessionId

                    return model.include(accessToken: accessToken).then =>
                        ret[@constructor.modelName] = model
                        facade.setSessionId oldSessionId
                        return ret

                else if include is 'recursive'
                    return model.include(accessToken: accessToken, recursive: true).then =>
                        ret[@constructor.modelName] = model
                        facade.setSessionId oldSessionId

                        return ret

                else
                    ret[@constructor.modelName] = model
                    return ret

            else
                return ret


    ###*
    logout (delete session)

    @param {String} sessionId
    @return {Promise}
    ###
    logout: (sessionId) ->
        [accessToken, userId] = @parseSessionId sessionId
        client = @getFacade().lbPromised.createUserClient(@constructor.modelName,
            debug: @client.debug
            accessToken: accessToken
        )

        client.logout(accessToken)


    ###*
    get user model by sessionId

    @method getBySessionId
    @param {String} sessionId
    @param {Object} [options]
    @param {Boolean|String} [options.include] include related models or not. if 'recursive' is set, recursively fetches submodels
    @return {Promise(Entity)}
    ###
    getBySessionId: (sessionId, options = {}) ->
        [accessToken, userId] = @parseSessionId sessionId
        client = @getFacade().lbPromised.createUserClient(@constructor.modelName,
            debug: @client.debug
            accessToken: accessToken
        )

        client.findById(userId).then (user) =>
            model = @factory.createFromObject user
            if options.include
                facade = @getFacade()
                oldSessionId = facade.sessionId
                facade.setSessionId sessionId

                return model.include(recursive: (options.include is 'recursive')).then ->
                    facade.setSessionId oldSessionId
                    return model

            else
                return model

        .catch (e) ->

            if e.isLoopBackResponseError
                return null

            throw e


    ###*
    confirm existence of account by email and password

    @param {String} email
    @param {String} password
    @return {Promise(Boolean)} existence of the account
    ###
    confirm: (email, password) ->
        @login(email, password).then (result) =>
            @logout(result.sessionId).then ->
                return true
        .catch (e) ->
            return false



module.exports = LoopbackUserRepository
