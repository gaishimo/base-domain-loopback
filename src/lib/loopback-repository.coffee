
MasterRepository = require('base-domain').MasterRepository
Entity = require('base-domain').Entity

moment = require 'moment'
###*
@class LoopbackRepository
@extends MasterRepository see https://github.com/cureapp/base-domain
###
class LoopbackRepository extends MasterRepository

    ###*
    by default, disable storing master table
    ###
    @storeMasterTable: off


    ###*
    model name used in LoopBack
    it will be the same value as @modelName if not set

    @property lbModelName
    @static
    @type String
    ###
    @lbModelName: ''


    ###*
    constructor

    @constructor
    @param {Object}  [options]
    @param {String}  [options.sessionId] Session ID
    @param {Boolean} [options.debug] shows debug log if true
    ###
    constructor: (options = {}) ->
        super()

        facade = @getFacade()
        lbModelName = @constructor.lbModelName or @constructor.modelName

        sessionId = options.sessionId or facade.sessionId

        [accessToken, userId] = @parseSessionId sessionId

        options.accessToken ?= accessToken
        options.debug       ?= facade.debug

        @client = facade.lbPromised.createClient(lbModelName, options)

    ###*
    convert 'date' type property for loopback format

    @method modifyDate
    @private
    @param {Entity|Object} data
    @return {void}
    ###
    modifyDate: (data) ->
        for dateProp in @getModelClass().getPropInfo().dateProps
            val = data[dateProp]
            if val?
                data[dateProp] = moment(val).toISOString()
        return


    ###*
    Update or insert a model instance

    @method save
    @public
    @param {Entity} entity
    @return {Promise(Entity)} entity (different instance from input)
    ###
    save: (entity) ->
        client = @getClientByEntity(entity)

        @modifyDate(entity)
        super(entity, client)

    ###*
    get object by ID.

    @method get
    @public
    @param {any} id
    @return {Promise(Entity)} entity
    ###
    get: (id, foreignKey) ->
        client = @getClientByForeignKey(foreignKey)
        super(id, client)


    ###*
    Find all model instances that match params

    @method query
    @public
    @param {Object} [params] query parameters
    @return {Promise(Array(Entity))} array of entities
    ###
    query: (params) ->
        client = @getClientByQuery(params)
        super(params, client)


    ###*
    Find one model instance that matches params, Same as query, but limited to one result

    @method singleQuery
    @public
    @param {Object} [params] query parameters
    @return {Promise(Entity)} entity
    ###
    singleQuery: (params) ->
        client = @getClientByQuery(params)
        super(params, client)



    ###*
    Destroy the given entity (which must have "id" value)

    @method delete
    @public
    @param {Entity} entity
    @return {Promise(Boolean)} isDeleted
    ###
    delete: (entity) ->
        client = @getClientByEntity(entity)
        super(entity, client)


    ###*
    Update set of attributes.

    @method update
    @public
    @param {any} id id of the entity to update
    @param {Object} data key-value pair to update
    @return {Promise(Entity)} updated entity
    ###
    update: (id, data) ->
        client = @getClientByEntity(data) # FIXME fails if data doesnt contain foreign key
        @modifyDate(data)
        super(id, data, client)




    ###*
    get client by entity. By default it returns @client

    @method getClientByEntity
    @protected
    @param {Entity} entity
    @return {LoopBackClient} client
    ###
    getClientByEntity: (entity) ->
        return @client


    ###*
    get client by foreign key. By default it returns @client

    @method getClientByForeignKey
    @protected
    @param {String} foreignKey
    @return {LoopBackClient} client
    ###
    getClientByForeignKey: (foreignKey) ->
        return @client


    ###*
    get client by query value. By default it returns @client

    @method getClientByQuery
    @protected
    @param {Object} query
    @return {LoopBackClient} client
    ###
    getClientByQuery: (query) ->
        return @client


    ###*
    get accessToken and userId by sessionId

    @method parseSessionId
    @protected
    @param {String} sessionId
    @return {Array(String)} [accessToken, userId]
    ###
    parseSessionId: (sessionId) ->
        if not sessionId
            return [null, null]
        return sessionId.split('/')



module.exports = LoopbackRepository