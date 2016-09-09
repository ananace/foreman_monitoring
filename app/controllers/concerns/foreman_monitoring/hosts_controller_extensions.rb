module ForemanMonitoring
  module HostsControllerExtensions
    extend ActiveSupport::Concern

    included do
      before_action :find_resource_with_monitoring, :only => [:downtime]
      before_action :find_multiple_with_monitoring, :only => [:select_multiple_downtime, :update_multiple_downtime]
      before_action :validate_host_downtime_params, :only => [:downtime]
      before_action :validate_hosts_downtime_params, :only => [:update_multiple_downtime]

      alias_method :find_resource_with_monitoring, :find_resource
      alias_method :find_multiple_with_monitoring, :find_multiple
    end

    def downtime
      unless @host.downtime_host(downtime_options)
        process_error(:redirect => host_path, :error_msg => @host.errors.full_messages.to_sentence)
        return false
      end
      process_success :success_msg => _('Created downtime for %s') % (@host), :success_redirect => :back
    end

    def select_multiple_downtime
    end

    def update_multiple_downtime
      failed_hosts = {}

      @hosts.each do |host|
        unless host.monitored?
          failed_hosts[host.name] = _('is not monitored')
          next
        end
        begin
          unless host.downtime_host(downtime_options)
            error_message = host.errors.full_messages.to_sentence
            failed_hosts[host.name] = error_message
            logger.error "Failed to set a host downtime for #{host}: #{error_message}"
          end
        rescue => error
          failed_hosts[host.name] = error
          Foreman::Logging.exception(_('Failed to set a host downtime for %s.') % host, error)
        end
      end

      if failed_hosts.empty?
        notice _('A downtime was set for the selected hosts.')
      else
        error n_('A downtime clould not be set for host: %s.',
                 'A downtime could not be set for hosts: %s.',
                 failed_hosts.count) % failed_hosts.map { |h, err| "#{h} (#{err})" }.to_sentence
      end
      redirect_back_or_to hosts_path
    end

    private

    def downtime_options
      {
        :comment => params[:downtime][:comment],
        :author => "Foreman User #{User.current}",
        :start_time => DateTime.parse(params[:downtime][:starttime]).to_time.to_i,
        :end_time => DateTime.parse(params[:downtime][:endtime]).to_time.to_i
      }
    end

    def validate_host_downtime_params
      validate_downtime_params(host_path)
    end

    def validate_hosts_downtime_params
      validate_downtime_params(hosts_path)
    end

    def validate_downtime_params(redirect_url)
      if params[:downtime].blank? || (params[:downtime][:comment]).blank?
        process_error(:redirect => redirect_url, :error_msg => 'No comment for downtime set!')
        return false
      end
      if (params[:downtime][:starttime]).blank? || (params[:downtime][:endtime]).blank?
        process_error(:redirect => redirect_url, :error_msg => 'No start/endtime for downtime!')
        return false
      end
      begin
        DateTime.parse(params[:downtime][:starttime])
        DateTime.parse(params[:downtime][:endtime])
      rescue ArgumentError
        process_error(:redirect => redirect_url, :error_msg => 'Invalid start/endtime for downtime!')
        return false
      end
    end

    def action_permission
      case params[:action]
      when 'downtime', 'select_multiple_downtime', 'update_multiple_downtime'
        :downtime
      else
        super
      end
    end
  end
end
