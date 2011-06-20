# Copyright (c) 2009-2011 VMware, Inc.
require "set"
require "datamapper"
require "uuidtools"

$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..', '..', '..', 'base', 'lib')
require 'base/node'

module VCAP
  module Services
    module Celery
      class Node < VCAP::Services::Base::Node
      end
    end
  end
end

require "celery_service/common"

VALID_CREDENTIAL_CHARACTERS = ("A".."Z").to_a + ("a".."z").to_a + ("0".."9").to_a

class VCAP::Services::Celery::Node

  include VCAP::Services::Celery::Common

  class ProvisionedService
    include DataMapper::Resource
    property :name,            String,      :key => true
    property :plan,            Enum[:free], :required => true
    property :plan_option,     String,      :required => false
    property :memory,          Integer,     :required => true
  end

  def initialize(options)
    super(options)
    @celeryctl = options[:celeryctl]
    @celeryd = options[:celeryd]
    @available_memory = options[:available_memory]
    @max_memory = options[:max_memory]
    @local_db = options[:local_db]
    @binding_options = ["configure", "write", "read"]
    @options = options

    @base_dir = options[:base_dir]
    FileUtils.mkdir_p(@base_dir) if @base_dir
  end

  def start
    @logger.info("Starting celery service node...")
    start_db
  end

  def start_db
    DataMapper.setup(:default, @local_db)
    DataMapper::auto_upgrade!
  end

  def announcement
    a = {
      :available_memory => @available_memory
    }
  end

  def provision(plan)
    service = ProvisionedService.new
    service.name = "celery-#{UUIDTools::UUID.random_create.to_s}"
    service.plan = plan
    service.plan_option = ""
    service.memory = @max_memory

    @available_memory -= service.memory

    save_provisioned_service(service)


    @logger.info("Provisioning service #{service.name}")
    response = {
       "name" => service.name,
       "hostname" => @local_ip,
    }
  rescue => e
    @available_memory += service.memory
    @logger.warn(e)
    nil
  end

  def unprovision(service_id, handles = {})
    service = get_provisioned_service(service_id)
    # Delete all bindings in this service
    handles.each do |handle|
      unbind(handle)
    end
    destroy_provisioned_service(service)
    @available_memory += service.memory
    true
  rescue => e
    @logger.warn(e)
    nil
  end

  def bind(service_id, binding_options = :all)
    @logger.info("Binding service #{service_id}")
    handle = {}
    service = get_provisioned_service(service_id)
    start_worker_node(service.name)
    handle["name"] = service.name
    handle["service_id"] = service_id
    handle["hostname"] = @local_ip
    handle
  rescue => e
    @logger.warn(e)
    nil
  end

  def unbind(handle)
    service = get_provisioned_service(handle["service_id"])
    stop_worker_node(service.name)
  rescue => e
    @logger.warn(e)
    nil
  end

  def save_provisioned_service(provisioned_service)
    raise "Could not save service: #{provisioned_service.errors.pretty_inspect}" unless provisioned_service.save
  end

  def destroy_provisioned_service(provisioned_service)
    raise "Could not delete service: #{provisioned_service.errors.pretty_inspect}" unless provisioned_service.destroy
  end

  def get_provisioned_service(service_id)
    provisioned_service = ProvisionedService.get(service_id)
    raise "Could not find service: #{service_id}" if provisioned_service.nil?
    provisioned_service
  end

  def start_worker_node(name)
    @logger.info("Starting worker node: #{name}...")
    %x[#{@celeryd} start #{name} --prefix=' ' -- broker.host=localhost]
  end

  def stop_worker_node(name)
    @logger.info("Stopping worker node: #{name}...")
    %x[#{@celeryd} stop #{name}]
  end

  def generate_credential(length = 12)
    Array.new(length) {VALID_CREDENTIAL_CHARACTERS[rand(VALID_CREDENTIAL_CHARACTERS.length)]}.join
  end
end
