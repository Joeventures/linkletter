class EmailTemplatesController < ApplicationController
  include GroupScoped

  # Preview of the saved template, rendered for a sample member.
  def show
    @email = @group.email_renderer.render(
      member_name: @group.members.first&.name || "Jane Doe",
      link_title: @group.links.first&.title.presence || "Sunday livestream",
      url: personal_redirect_url("ThisIsAPreviewOnlyPersonalLink12")
    )
  end

  def edit
    # Start from the built-in email so there is something to customize.
    @group.email_template = EmailTemplate::DEFAULT_BODY unless @group.email_renderer.custom_body?
  end

  def update
    if @group.update(template_params)
      redirect_to group_email_template_path(@group), notice: "Email template saved. Here's a preview."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # Reset to the built-in email.
  def destroy
    @group.rich_text_email_template&.destroy!
    @group.update!(email_subject: nil)
    redirect_to group_email_template_path(@group), notice: "Email template reset to the default.", status: :see_other
  end

  private
    def template_params
      params.expect(group: %i[ email_subject email_template ])
    end
end
