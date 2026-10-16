# Own origin only, no inline script or style: Rails adds the per-request nonce to the importmap,
# stylesheet and Turbo tags (csp_meta_tag lets Turbo pass it on to its own progress bar style).
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src :self
    policy.img_src :self, :data
    policy.object_src :none
    policy.base_uri :self
    policy.form_action :self
    policy.frame_ancestors :none
    policy.script_src :self
    policy.style_src :self
    policy.connect_src :self
  end

  config.content_security_policy_nonce_generator = ->(request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src style-src]
end
