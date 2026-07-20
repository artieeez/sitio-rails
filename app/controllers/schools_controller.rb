class SchoolsController < ApplicationController
  before_action :set_school, only: %i[ show edit update ]

  def index
    @include_inactive = ActiveModel::Type::Boolean.new.cast(params[:include_inactive])
    @schools = School.listed(include_inactive: @include_inactive)
  end

  def show
  end

  def new
    @school = School.new
  end

  def create
    @school = School.new(school_params)

    if @school.save
      redirect_to @school, notice: "Escola criada."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @school.update(school_params)
      redirect_to @school, notice: "Escola atualizada."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def set_school
      @school = School.find(params[:id])
    end

    def school_params
      params.require(:school).permit(
        :title, :description, :url, :image_url, :favicon_url, :wix_collection_id
      )
    end
end
