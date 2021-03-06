'use strict'

LoopbackRepository = require './loopback-repository'

###*
@class LoopbackUserRepository
@extends LoopbackRepository
@module base-domain-loopback
###
class LoopbackUserRepository extends LoopbackRepository
    ###*
    constructor

    @constructor
    @param {Object}  [options]
    @param {String}  [options.sessionId] Session ID
    @param {Boolean} [options.debug] shows debug log if true
    ###
    constructor: (options = {}, root) ->
        super(options, root)
        modelName = @constructor.modelName
        @client = @facade.lbPromised.createUserClient(modelName, options)



    ###*
    get sessionId from account information (email/password)

    @param {String} email
    @param {String} password
    @param {Boolean|String} [include] fetch related model if true. fetch submodels if 'include'.
    @return {Promise(Object)}
    ###
    login: (email, password, include) ->
        facade = @facade

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
                ret.user = model

                if include is 'include'
                    oldSessionId = facade.sessionId
                    facade.setSessionId ret.sessionId

                    return model.$include(accessToken: accessToken).then (newModel) =>
                        ret[@constructor.modelName] = newModel
                        ret.user = newModel
                        facade.setSessionId oldSessionId
                        return ret

                else
                    ret[@constructor.modelName] = model
                    ret.user = model
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
        client = @facade.lbPromised.createUserClient(@constructor.modelName,
            debug: @client.debug
            accessToken: accessToken
        )

        client.logout(accessToken)


    ###*
    get user model by sessionId

    @method getBySessionId
    @param {String} sessionId
    @param {Object} [options]
    @param {Boolean|String} [options.include] include related models or not.
    @return {Promise(Entity)}
    ###
    getBySessionId: (sessionId, options = {}) ->
        [accessToken, userId] = @parseSessionId sessionId
        client = @facade.lbPromised.createUserClient(@constructor.modelName,
            debug: @client.debug
            accessToken: accessToken
        )

        client.findById(userId).then (user) =>
            model = @factory.createFromObject user
            if options.include
                facade = @facade
                oldSessionId = facade.sessionId
                facade.setSessionId sessionId

                return model.include().then ->
                    facade.setSessionId oldSessionId
                    return model

            else
                return model

        .catch (e) ->

            if e.isLoopbackResponseError
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


    ###*
    Override original method.
    Enable to preserve password property using `__password` option.
    Mainly for immutable entities.
    ###
    createFromResult: (obj, options = {}) ->
        return super if not options.__password?
        obj.password = options.__password
        return super(obj, options)


    ###*
    Update or insert a model instance
    reserves password property, as loopback does not return password

    @method save
    @public
    @param {Entity|Object} entity
    @return {Promise(Entity)} entity (the same instance from input, if entity given,)
    ###
    save: (entity, options = {}) ->

        options.__password = entity?.password

        super(entity, options)


module.exports = LoopbackUserRepository
