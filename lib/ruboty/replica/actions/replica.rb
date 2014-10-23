module Ruboty
  module Replica
    module Actions
      class Replica < Ruboty::Actions::Base
        def call
          replica = replicate!
          message.reply("replica: replicated #{message.robot.name} to #{replica['name']}")
          message.reply("replica: #{replica['git_url']}")

          if message[:new_owner]
            transfer!(replica, message[:new_owner])
          end
        rescue => e
          message.reply("replica: failed, #{e.message}")
        end

        private

        def transfer!(replica, recipient)
          heroku.collaborator.create(replica['name'], user: recipient)
          message.reply("replica: collaborator #{recipient} added")

          heroku.app_transfer.create(app: replica['name'], recipient: recipient)
          message.reply("replica: #{recipient} is now owner of #{replica['name']}")
        end

        def replicate!
          replica = heroku.app.create({})

          message.reply("replica: my name is #{replica['name']}")

          heroku.config_var.update(
            replica['name'],
            replicable_config_vars.merge({
              'HEROKU_APP_NAME' => replica['name'],
              'ROBOT_NAME' => replica['name']
            })
          )

          message.reply("replica: replicated env #{replicable_config_vars.keys.join(', ')}")

          addons.each do |addon|
            heroku.addon.create(replica['name'], {plan: addon['plan']['name']})
            message.reply("replica: addon created #{addon['plan']['name']}")
          end

          heroku.release.create(replica['name'], slug: latest_release['slug']['id'])
          message.reply("replica: slug copied")

          heroku.formation.batch_update(replica['name'], {"updates" => replica_formations})
          formation_text = replica_formations.map {|f|
            "#{f[:process]} (#{f[:size]}): #{f[:quantity]}"
          }.join(', ')
          message.reply("replica: #{formation_text}")

          replica
        end

        def app
          @app ||= heroku.app.info(heroku_app_name)
        end

        def app_config_vars
          @app_config_vars ||= heroku.config_var.info(heroku_app_name)
        end

        def app_formations
          heroku.formation.list(app['name'])
        end

        def replica_formations
          app_formations.map {|f| {process: f['type'], quantity: f['quantity'], size: f['size']} }
        end

        def replicable_config_vars
          app_config_vars.except(*addon_config_var_keys, 'ROBOT_NAME', 'HEROKU_APP_NAME')
        end

        def addons
          @addons ||= heroku.addon.list(heroku_app_name)
        end

        def addon_config_var_keys
          addons.map {|addon| addon['config_vars'] }.flatten
        end

        def latest_release
          releases.sort_by {|r| r['version'] }.last
        end

        def releases
          @releases ||= heroku.release.list(heroku_app_name)
        end

        def heroku
          require 'platform-api'
          @heroku ||= PlatformAPI.connect(heroku_api_key)
        end

        def heroku_app_name
          ENV['HEROKU_APP_NAME']
        end

        def heroku_api_key
          ENV['HEROKU_API_KEY']
        end
      end
    end
  end
end
