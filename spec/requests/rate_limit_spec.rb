require 'rails_helper'

RSpec.describe "Rate Limiting System", type: :request do
  before do
    Rack::Attack.enabled = true
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    Rack::Attack.reset!
  end

  after do
    Rack::Attack.enabled = false
  end

  describe "Chống spam tra cứu thời tiết" do
    it "cho phép tìm kiếm 10 lần đầu và chặn từ lần thứ 11 (HTTP 429)" do
      10.times do
        get "/", params: { city: "Hanoi" }
        expect(response.status).not_to eq(429)
      end

      get "/", params: { city: "Hanoi" }
      expect(response.status).to eq(429)
    end
  end
end