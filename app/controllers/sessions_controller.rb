class SessionsController < ApplicationController
    def new
    end
    def save
        user = User.find_by(email: params[:email])
        if user && user.authenticate(params[:password])
            cookies.encrypted[:user_id] = {
                value: user.id,
                expires: 30.minutes.from_now,
                httponly: true
            }
            if (user.is_verified? == false) 
                redirect_to otp_path
            else 
            redirect_to root_path, notice: "Đăng nhập thành công"
            end
        else
            flash.now[:alert] = "Tài khoản hoặc mật khẩu không chính xác"
            render :new
        end
    end
    def google_login
        auth = request.env['omniauth.auth']
        user = auth.present? ? User.from_omniauth(auth) : nil
        if user && user.persisted?
            cookies.encrypted[:user_id] = {
                value: user.id,
                expires: 30.minutes.from_now,
                httponly: true
            }
            redirect_to root_path, notice: "Đăng nhập thành công"
        else
            flash[:alert] ="Đăng nhập thất bại. vui lòng thử lại"
            redirect_to login_path
        end
    end
    def destroy
        cookies.delete(:user_id) 
        redirect_to root_path, notice: "Đăng xuất thành công"
    end
end

