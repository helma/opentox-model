require 'rubygems'
gem "opentox-ruby", "~> 0"
require 'opentox-ruby'

class ModelStore
	include DataMapper::Resource
	attr_accessor :prediction_dataset, :subjectid
	property :id, Serial
	property :uri, String, :length => 255
	property :yaml, Text, :length => 2**32-1 
	property :created_at, DateTime
	
  @subjectid = nil

  after :save, :check_policy
  
  private
  def check_policy
    OpenTox::Authorization.check_policy(uri, subjectid)
  end
	
end

class PredictionCache
  # cache predictions
	include DataMapper::Resource
	property :id, Serial
	property :compound_uri, String, :length => 255
	property :model_uri, String, :length => 255
	property :dataset_uri, String, :length => 255
end

DataMapper.auto_upgrade!

require 'lazar.rb'
#require 'property_lazar.rb'


helpers do
	def activity(a)
		case a.to_s
		when "true"
			act = "active"
		when "false"
			act = "inactive"
		else
			act = "not available"
		end
		act
	end
end

get '/?' do # get index of models
	response['Content-Type'] = 'text/uri-list'
	params.delete_if{|k,v| k=="subjectid"}
	ModelStore.all(params).collect{|m| m.uri}.join("\n") + "\n"
end

delete '/:id/?' do
  begin
    uri = ModelStore.get(params[:id]).uri
    ModelStore.get(params[:id]).destroy!
    "Model #{params[:id]} deleted."

    if @subjectid and !ModelStore.get(params[:id]) and uri
      begin
        res = OpenTox::Authorization.delete_policies_from_uri(uri, @subjectid)
        LOGGER.debug "Policy deleted for Model URI: #{uri} with subjectid: #{@subjectid} with result: #{res}"
      rescue
        LOGGER.warn "Policy delete error for Model URI: #{uri}"
      end
    end
    response['Content-Type'] = 'text/plain'
    "Model #{params[:id]} deleted."
  rescue
    halt 404, "Model #{params[:id]} does not exist."
  end
end


delete '/?' do
	# TODO delete datasets
  ModelStore.auto_migrate!
  #Prediction.auto_migrate!
	response['Content-Type'] = 'text/plain'
	"All models and cached predictions deleted."
end
