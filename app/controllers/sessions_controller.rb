class SessionsController < ApplicationController
    def new
    end
    def save
        user = User.find_by(email: params[:email])
        if user.authenticate(params[:password])
            if (user.is_verified? == false) 
                redirect_to otp_path
            else 
            cookies.encrypted[:user_id] = {
                value: user.id,
                expires: 30.minutes.from_now,
                httponly: true
            }

            redirect_to root_path, notice: "Đăng nhập thành công"
            end
        else
            flash.now[:alert] = "Tài khoản hoặc mật khẩu không chính xác"
            render :new
        end
    end
    def destroy
        cookies.delete(:user_id) 
        redirect_to root_path, notice: "Đăng xuất thành công"
    end
end

