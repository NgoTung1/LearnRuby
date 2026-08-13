require 'rails_helper'

RSpec.describe ChatbotsController, type: :controller do
  describe 'POST #chat' do
    context 'khi tin nhắn bị bỏ trống' do
      it 'trả về lỗi yêu cầu nhập câu hỏi' do
        post :chat, params: { message: '   ' }
        
        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to eq(false)
        expect(json_response['reply']).to eq('Vui lòng nhập câu hỏi!')
      end
    end

    context 'khi tin nhắn quá dài' do
      it 'trả về lỗi yêu cầu rút gọn câu hỏi' do
        long_message = 'a' * 501
        post :chat, params: { message: long_message }
        
        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to eq(false)
        expect(json_response['reply']).to eq('Câu hỏi quá dài, vui lòng rút gọn lại!')
      end
    end

    context 'khi tin nhắn hợp lệ' do
      let(:mock_service) { instance_double(ChatbotRagService) }
      let(:valid_message) { 'Thời tiết hôm nay thế nào?' }
      let(:current_city) { 'Hà Nội' }

      before do
        allow(ChatbotRagService).to receive(:new).with(valid_message, current_city: current_city).and_return(mock_service)
        allow(mock_service).to receive(:call).and_return({
          success: true,
          reply: 'Trời nắng đẹp.',
          city: 'Hà Nội'
        })
      end

      it 'gọi ChatbotRagService và trả về kết quả thành công' do
        post :chat, params: { message: valid_message, current_city: current_city }
        
        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to eq(true)
        expect(json_response['reply']).to eq('Trời nắng đẹp.')
        expect(json_response['city']).to eq('Hà Nội')
      end
    end
  end
end
