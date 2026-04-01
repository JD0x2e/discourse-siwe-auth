# frozen_string_literal: true

# name: discourse-siwe
# about: A discourse plugin to enable users to authenticate via Sign In with Ethereum
# version: 0.1.3

# rbsecp256k1 requires rubyzip ~> 2.3 but only at build time, not runtime.
# Discourse ships rubyzip 3.x which triggers a conflict on activation.
# This patches the exact method that raises Gem::ConflictError.
unless defined?(SIWE_RUBYZIP_PATCHED)
  SIWE_RUBYZIP_PATCHED = true
  Gem::Dependency.prepend(Module.new do
    def matches_spec?(spec)
      return true if name == 'rubyzip' && spec.name == 'rubyzip'
      super
    end
  end)
end

enabled_site_setting :discourse_siwe_enabled
register_svg_icon 'fab-ethereum'
register_asset 'stylesheets/discourse-siwe.scss'

%w[
  ../lib/omniauth/strategies/siwe.rb
].each { |path| load File.expand_path(path, __FILE__) }

gem 'pkg-config', '1.5.6', require: false
gem 'forwardable', '1.3.3', require: false
gem 'mkmfmf', '0.4', require: false
gem 'keccak', '1.3.0', require: false
gem 'zip', '2.0.2', require: false
gem 'mini_portile2', '2.8.0', require: false

# Patch rbsecp256k1 gemspec to remove rubyzip runtime dependency
gems_dir = File.join(File.dirname(__FILE__), "gems")
if Dir.exist?(gems_dir)
  Dir[File.join(gems_dir, "*", "specifications", "rbsecp256k1-*.gemspec")].each do |gemspec_path|
    content = File.read(gemspec_path)
    if content.include?('rubyzip') && !content.include?('# patched-rubyzip')
      patched = content.gsub(/[^\n]*rubyzip[^\n]*\n/, '')
      File.write(gemspec_path, "# patched-rubyzip\n" + patched)
    end
  end
end

gem 'rbsecp256k1', '6.0.0', require: false
gem 'konstructor', '1.0.2', require: false
gem 'ffi', '1.17.2', require: false
gem 'ffi-compiler', '1.0.1', require: false
gem 'scrypt', '3.0.7', require: false
gem 'eth', '0.5.11', require: false
gem 'siwe', '1.1.2', require: false

class ::SiweAuthenticator < ::Auth::ManagedAuthenticator
  def name
    'siwe'
  end

  def register_middleware(omniauth)
    omniauth.provider :siwe,
                      setup: lambda { |env|
                        strategy = env['omniauth.strategy']
                      }
  end

  def enabled?
    SiteSetting.discourse_siwe_enabled
  end

  def primary_email_verified?
    false
  end
end

auth_provider authenticator: ::SiweAuthenticator.new,
              icon: 'fab-ethereum',
              full_screen_login: true

after_initialize do
  %w[
    ../lib/discourse_siwe/engine.rb
    ../lib/discourse_siwe/routes.rb
    ../app/controllers/discourse_siwe/auth_controller.rb
  ].each { |path| load File.expand_path(path, __FILE__) }

  Discourse::Application.routes.prepend do
    mount ::DiscourseSiwe::Engine, at: '/discourse-siwe'
  end
end
