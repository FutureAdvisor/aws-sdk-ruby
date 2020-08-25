# frozen_string_literal: true

require 'aws-sigv4'

module Aws
  module RDS
    module Plugins
      # This plugin populates the `:pre_signed_url` request param for the
      # CopyDBSnapshot API.
      #
      # This parameter is required by RDS when copying an encrypted snapshot
      # across regions. This plugin will be skipped if the `:pre_signed_url`
      # parameter is provided by the user.
      class CrossRegionCopying < Seahorse::Client::Plugin
        # @api private
        class Handler < Seahorse::Client::Handler
          def call(context)
            params = context.params
            if params.is_a?(Hash) &&
               params[:source_region] && !params[:pre_signed_url]
              params[:pre_signed_url] = presigned_url(context, params)
              # params[:destination_region] = context.config.region
            end
            @handler.call(context)
          end

          private

          def presigned_url(context, params)
            # :source_region is not modeled in the api
            source_region = params.delete(:source_region)
            param_list = Aws::Query::ParamList.new
            param_list.set('Action', context.operation.name)
            param_list.set('DestinationRegion', context.config.region)
            param_list.set('Version', context.config.api.version)
            Aws::Query::ParamBuilder.new(param_list).apply(
              context.operation.input,
              params
            )
            signer = Aws::Sigv4::Signer.new(
              service: 'rds',
              region: source_region,
              credentials_provider: context.config.credentials
            )
            url = Aws::Partitions::EndpointProvider.resolve(
              signer.region, 'rds'
            )
            url += "?#{param_list}"
            signer.presign_url(
              http_method: 'GET',
              url: url,
              body: '',
              expires_in: 3600
            ).to_s
          end
        end

        handler(
          Handler,
          step: :initialize,
          operations: [
            :copy_db_snapshot,
            :create_db_instance_read_replica,
            :copy_db_cluster_snapshot,
            :create_db_cluster
          ]
        )
      end
    end
  end
end
