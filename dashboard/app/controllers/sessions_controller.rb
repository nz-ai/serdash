# frozen_string_literal: true

class SessionsController < ApplicationController
  def create
    user = User.from_omniauth(request.env["omniauth.auth"])
    session[:user_id] = user.id
    redirect_to root_path, notice: "Signed in successfully."
  rescue StandardError => e
    redirect_to root_path, alert: "Authentication failed: #{e.message}"
  end

  def destroy
    session.delete(:user_id)
    redirect_to root_path, notice: "Signed out."
  end

  def failure
    redirect_to root_path, alert: "Authentication failed."
  end
end
