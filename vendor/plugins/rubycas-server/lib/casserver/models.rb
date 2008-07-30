require 'camping/db'

module CASServer::Models
  
  module Consumable
    def consume!
      self.consumed = Time.now
      self.save!
    end
  end
  
  class Ticket < Base
    def to_s
      ticket
    end
    
    def self.cleanup_expired(expiry_time)
      transaction do
        conditions = ["created_on < ?", Time.now - expiry_time]
        expired_tickets_count = count(:conditions => conditions)
          
        $LOG.debug("Destroying #{expired_tickets_count} expired #{self.name.split('::').last}"+
          "#{'s' if expired_tickets_count > 1}.") if expired_tickets_count > 0
      
        destroy_all(conditions)
      end
    end
  end
  
  class LoginTicket < Ticket
    set_table_name 'casserver_lt'
    include Consumable
  end
  
  class ServiceTicket < Ticket
    set_table_name 'casserver_st'
    include Consumable
    
    belongs_to :ticket_granting_ticket, :foreign_key => :tgt_id
    
    def matches_service?(service)
      CASServer::CAS.clean_service_url(self.service) == 
        CASServer::CAS.clean_service_url(service)
    end
  end
  
  class ProxyTicket < ServiceTicket
    belongs_to :proxy_granting_ticket
  end
  
  class TicketGrantingTicket < Ticket
    set_table_name 'casserver_tgt'
    
    serialize :extra_attributes
    
    has_many :service_tickets, :foreign_key => :tgt_id
  end
  
  class ProxyGrantingTicket < Ticket
    set_table_name 'casserver_pgt'
    belongs_to :service_ticket
    has_many :proxy_tickets, :dependent => :destroy
  end
  
  class Error
    attr_reader :code, :message
    
    def initialize(code, message)
      @code = code
      @message = message
    end
    
    def to_s
      message
    end
  end

  class CreateCASServer < V 0.1
    def self.up
      if ActiveRecord::Base.connection.table_alias_length > 30
        $LOG.info("Creating database with long table names...")
        
        create_table :casserver_login_tickets, :force => true do |t|
          t.column :ticket,     :string,   :null => false
          t.column :created_on, :timestamp, :null => false
          t.column :consumed,   :datetime, :null => true
          t.column :client_hostname, :string, :null => false
        end
      
        create_table :casserver_service_tickets, :force => true do |t|
          t.column :ticket,     :string,    :null => false
          t.column :service,    :string,    :null => false
          t.column :created_on, :timestamp, :null => false
          t.column :consumed,   :datetime, :null => true
          t.column :client_hostname, :string, :null => false
          t.column :username,   :string,  :null => false
          t.column :type,       :string,   :null => false
          t.column :proxy_granting_ticket_id, :integer, :null => true
        end
        
        create_table :casserver_ticket_granting_tickets, :force => true do |t|
          t.column :ticket,     :string,    :null => false
          t.column :created_on, :timestamp, :null => false
          t.column :client_hostname, :string, :null => false
          t.column :username,   :string,    :null => false
        end
        
        create_table :casserver_proxy_granting_tickets, :force => true do |t|
          t.column :ticket,     :string,    :null => false
          t.column :created_on, :timestamp, :null => false
          t.column :client_hostname, :string, :null => false
          t.column :iou,        :string,    :null => false
          t.column :service_ticket_id, :integer, :null => false
        end
      end
    end
    
    def self.down
      if ActiveRecord::Base.connection.table_alias_length > 30
        drop_table :casserver_proxy_granting_tickets
        drop_table :casserver_ticket_granting_tickets
        drop_table :casserver_service_tickets
        drop_table :casserver_login_tickets
      end
    end
  end
  
  # Oracle table names cannot exceed 30 chars... 
  # See http://code.google.com/p/rubycas-server/issues/detail?id=15
  class ShortenTableNames < V 0.5
    def self.up
      if ActiveRecord::Base.connection.table_alias_length > 30
        $LOG.info("Shortening table names")
        rename_table :casserver_login_tickets, :casserver_lt
        rename_table :casserver_service_tickets, :casserver_st
        rename_table :casserver_ticket_granting_tickets, :casserver_tgt
        rename_table :casserver_proxy_granting_tickets, :casserver_pgt
      else
        create_table :casserver_lt, :force => true do |t|
          t.column :ticket,     :string,   :null => false
          t.column :created_on, :timestamp, :null => false
          t.column :consumed,   :datetime, :null => true
          t.column :client_hostname, :string, :null => false
        end
      
        create_table :casserver_st, :force => true do |t|
          t.column :ticket,     :string,    :null => false
          t.column :service,    :string,    :null => false
          t.column :created_on, :timestamp, :null => false
          t.column :consumed,   :datetime, :null => true
          t.column :client_hostname, :string, :null => false
          t.column :username,   :string,  :null => false
          t.column :type,       :string,   :null => false
          t.column :proxy_granting_ticket_id, :integer, :null => true
        end
        
        create_table :casserver_tgt, :force => true do |t|
          t.column :ticket,     :string,    :null => false
          t.column :created_on, :timestamp, :null => false
          t.column :client_hostname, :string, :null => false
          t.column :username,   :string,    :null => false
        end
        
        create_table :casserver_pgt, :force => true do |t|
          t.column :ticket,     :string,    :null => false
          t.column :created_on, :timestamp, :null => false
          t.column :client_hostname, :string, :null => false
          t.column :iou,        :string,    :null => false
          t.column :service_ticket_id, :integer, :null => false
        end
      end
    end
    
    def self.down
      if ActiveRecord::Base.connection.table_alias_length > 30
        rename_table :casserver_lt, :cassserver_login_tickets
        rename_table :casserver_st, :casserver_service_tickets
        rename_table :casserver_tgt, :casserver_ticket_granting_tickets
        rename_table :casserver_pgt, :casserver_proxy_granting_tickets
      else
        drop_table :casserver_pgt
        drop_table :casserver_tgt
        drop_table :casserver_st
        drop_table :casserver_lt
      end
    end
  end
  
  class AddTgtToSt < V 0.7
    def self.up
      add_column :casserver_st, :tgt_id, :integer, :null => true
    end
    
    def self.down
      remove_column :casserver_st, :tgt_id, :integer
    end
  end
  
  class ChangeServiceToText < V 0.71
    def self.up
      change_column :casserver_st, :service, :text
    end
    
    def self.down
      change_column :casserver_st, :service, :string
    end
  end
  
  class AddExtraAttributes < V 0.72
    def self.up
      add_column :casserver_tgt, :extra_attributes, :text
    end
    
    def self.down
      remove_column :casserver_tgt, :extra_attributes
    end
  end
end