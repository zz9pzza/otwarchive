class Application < ActiveRecord::Base
  include ActiveModel::ForbiddenAttributesProtection
end
