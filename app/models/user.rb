require 'casserver/authenticators/sql_encrypted'
class User < ActiveRecord::Base
  include CASServer::Authenticators::SQLEncrypted::EncryptedPassword
  attr_accessor :new_password

  validates_presence_of     :new_password
  validates_confirmation_of :new_password

  before_save { |u| u.password = u.new_password }
end
