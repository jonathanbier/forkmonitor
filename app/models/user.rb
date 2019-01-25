class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # registerable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :recoverable, :rememberable, :validatable, :confirmable, :jwt_authenticatable, jwt_revocation_strategy: JWTBlacklist
end
