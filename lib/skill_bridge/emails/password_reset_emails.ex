defmodule SkillBridge.Emails.PasswordResetEmails do
  import Swoosh.Email

  @from {"Skill Bridge", "noreply@skillbridge.local"}

  def password_reset(user, token) do
    reset_url = "http://localhost:4000/password-reset/#{token}"

    new()
    |> to({user.name, user.email})
    |> from(@from)
    |> subject("Reset your Skill Bridge password")
    |> html_body("""
    <p>Hi #{user.name},</p>
    <p>We received a request to reset your password. Click the link below to set a new one:</p>
    <p><a href="#{reset_url}" style="padding:10px 20px;background:#1e293b;color:white;border-radius:8px;text-decoration:none;display:inline-block;">Reset Password</a></p>
    <p>This link expires in 2 hours. If you didn't request this, you can safely ignore this email.</p>
    """)
    |> text_body("""
    Hi #{user.name},

    We received a request to reset your Skill Bridge password.
    Use this link to reset it (expires in 2 hours):

    #{reset_url}

    If you didn't request this, you can safely ignore this email.
    """)
  end
end
