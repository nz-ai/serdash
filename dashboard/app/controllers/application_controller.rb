# frozen_string_literal: true

class ApplicationController < ActionController::Base
  helper_method :current_user, :signed_in?

  private

  def current_user
    return @current_user if defined?(@current_user)
    @current_user = User.find_by(id: session[:user_id]) if session[:user_id]
    # Development stub: no OAuth needed
    if Rails.env.development? && @current_user.nil?
      @current_user = User.find_or_create_by!(email: "dev@localhost", provider: "development") do |u|
        u.uid = "stub"
      end
    end
    @current_user
  end

  def signed_in?
    current_user.present?
  end

  def require_login
    redirect_to root_path, alert: "Please sign in." unless signed_in?
  end
end
