require "spec"

module SandstoneExample
  ADAPTERS = ["pg","mysql","sqlite"]
  @@model_classes = [] of Sandstone::ORM::Base.class

  extend self

  def model_classes
    @@model_classes
  end
end

require "../src/sandstone"
require "./spec_models"

Sandstone::ORM.settings.logger = ::Logger.new(nil)

SandstoneExample.model_classes.each do |model|
  model.drop_and_create
end
