class SessionController < ApplicationController
    def new
    end
    def save
        user = user.find_by(params[:email])
        if user.authenticate(params[:password])
            cookies.encrypted[:user_id] = {
                value: user_id,
                expires: 30.minutes.from_now,
                httponly: true
            }

            redirect_to root_path, notice: "Đăng nhập thành công"
        else
            flash.now[:alrt] = "Tài khoản hoặc mật khẩu không chính xác"
            render :new
        end
    end
    def destroy
        cookies.delete(:user_id) 
        redirect_to root_path, notice: "Đăng xuất thành công"
    end
end

