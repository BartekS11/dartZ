Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins "*"  # tighten this to your mobile app domain in production

    resource "/api/*",
      headers: :any,
      methods: [ :get, :post, :put, :patch, :delete, :options, :head ],
      expose:  [ "Authorization" ]
  end
end
