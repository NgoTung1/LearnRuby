class User < ApplicationRecord
    has_secure_password
    has_many :favorites, dependent: :destroy
    has_many :search_histories, dependent: :destroy
    validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP}
    def generate_otp! 
        self.otp_code = rand(100000..999999).to_s
        self.otp_expires_at = 10.minutes.from_now
        save!
    end

    def check_otp?(code)
        otp_code == code && otp_expires_at.present? && otp_expires_at > Time.current
    end

    def resend_otp?
        otp_expires_at.nil? || Time.current >= otp_expires_at - 8.minutes
    end
end
