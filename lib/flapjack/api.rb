#!/usr/bin/env ruby

require 'flapjack/pikelet'

require 'flapjack/data/entity'
require 'flapjack/data/entity_check'

module Flapjack

  class API < Sinatra::Base

    extend Flapjack::Pikelet

    before do
      # will only initialise the first time it's run
      Flapjack::API.bootstrap
    end

    helpers do
      def json_status(code, reason)
        status code
        {:status => code, :reason => reason}.to_json
      end

      def logger
        Flapjack::API.logger
      end

    end

    def to_entity(name_or_entity)
      return name_or_entity if name_or_entity.is_a?(Flapjack::Data::Entity)
      Flapjack::Data::Entity.find_by_name(name_or_entity, :redis => @@redis)
    end

    def entity_status(ent)
      entity = to_entity(ent)
      return if entity.nil?
      entity.check_list.sort.collect {|check|
        entity_check_status(entity, check)
      }
    end

    def entity_check_status(ent, check)
      entity_check = Flapjack::Data::EntityCheck.new(:entity => to_entity(ent),
        :check => check, :redis => @@redis)
      return if entity_check.nil?
      { 'name'                                => check,
        'state'                               => entity_check.state,
        'in_unscheduled_maintenance'          => entity_check.in_unscheduled_maintenance?,
        'in_scheduled_maintenance'            => entity_check.in_scheduled_maintenance?,
        'last_update'                         => entity_check.last_update,
        'last_problem_notification'           => entity_check.last_problem_notification,
        'last_recovery_notification'          => entity_check.last_recovery_notification,
        'last_acknowledgement_notification'   => entity_check.last_acknowledgement_notification
      }
    end

    get '/entities' do
      content_type :json
      ret = Flapjack::Data::Entity.all(:redis => @@redis).sort_by(&:name).collect {|e|
        entity_status(e)
      }
      ret.to_json
    end

    get '/checks/:entity' do
      content_type :json
      entity = to_entity(params[:entity])
      p entity
      if entity.nil?
        status 404
        return
      end
      entity.check_list.to_json
    end

    get '/status/:entity' do
      content_type :json
      sta = entity_status(params[:entity])
      if sta.nil?
        status 404
        return
      end
      sta.to_json
    end

    get '/status/:entity/:check' do
      content_type :json
      sta = entity_check_status(params[:entity], params[:check])
      if sta.nil?
        status 404
        return
      end
      sta.to_json
    end

    # list scheduled maintenance periods for a service on an entity
    get '/scheduled_maintenances/:entity/:check' do
      content_type :json
      entity = to_entity(params[:entity])
      if entity.nil?
        status 404
        return
      end      
      entity_check = Flapjack::Data::EntityCheck.new(:entity => entity,
        :check => params[:check], :redis => @@redis)
      entity_check.scheduled_maintenances.to_json
    end

    # list unscheduled maintenance periods for a service on an entity
    get '/unscheduled_maintenances/:entity/:check' do
      content_type :json
      entity = to_entity(params[:entity])
      if entity.nil?
        status 404
        return
      end 
      entity_check = Flapjack::Data::EntityCheck.new(:entity => entity,
        :check => params[:check], :redis => @@redis)
      entity_check.unscheduled_maintenances.to_json
    end

    # create a scheduled maintenance period for a service on an entity
    post '/scheduled_maintenances/:entity/:check' do
      content_type :json
      entity = to_entity(params[:entity])
      if entity.nil?
        status 404
        return
      end       
      entity_check = Flapjack::Data::EntityCheck.new(:entity => entity,
        :check => params[:check], :redis => @@redis)
      entity_check.create_scheduled_maintenance(:start_time => params[:start_time],
        :duration => params[:duration], :summary => params[:summary])
      status 201
    end

    # create an acknowledgement for a service on an entity
    post '/acknowledgements/:entity/:check' do
      content_type :json
      entity = to_entity(params[:entity])
      if entity.nil?
        status 404
        return
      end       
      entity_check = Flapjack::Data::EntityCheck.new(:entity => entity,
        :check => params[:check], :redis => @@redis)
      entity_check.create_acknowledgement(params[:summary])
      status 201
    end

    not_found do
      json_status 404, "Not found"
    end

    error do
      json_status 500, env['sinatra.error'].message
    end

  end

end