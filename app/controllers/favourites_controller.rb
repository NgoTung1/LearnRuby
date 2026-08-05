class FavouritesController < ApplicationController
  before_action :require_verified_user

  def index
    @favorite_weathers = current_user.favorites.order(created_at: :desc).map do |fav|
      weather_res = WeatherApiService.fetch_cached(fav.city_name)
      {
        id: fav.id,
        city_name: fav.city_name,
        weather: weather_res[:success] ? weather_res[:data] : nil
      }
    end
  end

  def create
    city_name = params[:city_name]
    favorite = current_user.favorites.find_or_initialize_by(city_name: city_name)

    if favorite.save
      render json: { success: true, action: 'created', favorite_id: favorite.id, city_name: favorite.city_name }
    else
      render json: { success: false, error: favorite.errors.full_messages.join(", ") }, status: :unprocessable_entity
    end
  end

  def destroy
    favorite = current_user.favorites.find_by(id: params[:id])

    if favorite
      favorite.destroy
      respond_to do |format|
        format.json { render json: { success: true, action: 'destroyed' } }
        format.html { redirect_to favorites_path, notice: "Đã xóa khỏi danh sách yêu thích." }
      end
    else
      respond_to do |format|
        format.json { render json: { success: false, error: "Không tìm thấy" }, status: :not_found }
        format.html { redirect_to favorites_path, alert: "Không tìm thấy thành phố." }
      end
    end
  end

end