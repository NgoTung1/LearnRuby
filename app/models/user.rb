class User < ApplicationRecord
    has_secure_password validations: false
    has_many :favorites, dependent: :destroy
    has_many :search_histories, dependent: :destroy
    validates :email, 
        presence: { message: "không được để trống" }, 
        uniqueness: { message: "đã tồn tại trong hệ thống" }, 
        format: { with: URI::MailTo::EMAIL_REGEXP, message: "không đúng định dạng" }
    validates :password, presence: 
    { message: "không được để trống" }, 
    confirmation: 
    { message: "xác nhận không trùng khớp" },
    on: :create
    def generate_otp! 
        self.otp_code = rand(100000..999999).to_s
        self.otp_expires_at = 10.minutes.from_now
        save!

        UserMailer.otp_email(self).deliver_later
    end

    def check_otp?(code)
        otp_code == code && otp_expires_at.present? && otp_expires_at > Time.current
    end

    def resend_otp?
        otp_expires_at.nil? || Time.current >= otp_expires_at - 8.minutes
    end
end
