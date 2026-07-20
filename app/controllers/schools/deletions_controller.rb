class Schools::DeletionsController < ApplicationController
  include SchoolScoped

  def show
    @deletion = @school.deletion
  end

  def destroy
    @school.deletion.perform
    redirect_to schools_path, notice: "Escola excluída."
  rescue School::Deletion::NotAllowed => error
    redirect_to school_deletion_path(@school), alert: error.message
  end
end
