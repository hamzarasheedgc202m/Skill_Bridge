defmodule SkillBridge.Emails.BookingEmails do
  @moduledoc """
  Email content for booking lifecycle: requested, confirmed, cancelled.
  """
  import Swoosh.Email

  @from {"Skill Bridge", "noreply@skillbridge.local"}

  def booking_requested(booking) do
    profile = booking.skilled_profile
    user = profile.user
    client = booking.user
    service = profile.skill_category.name
    dt = format_dt(booking.scheduled_at)

    new()
    |> to({user.name, user.email})
    |> from(@from)
    |> subject("New booking request: #{service} on #{dt}")
    |> html_body("""
    <p>Hi #{user.name},</p>
    <p><strong>#{client.name}</strong> has requested a booking:</p>
    <ul>
      <li><strong>Service:</strong> #{service}</li>
      <li><strong>When:</strong> #{dt}</li>
      <li><strong>Address:</strong> #{booking.address}</li>
      #{if booking.notes && booking.notes != "", do: "<li><strong>Notes:</strong> #{booking.notes}</li>", else: ""}
    </ul>
    <p>Log in to Skill Bridge to confirm or reject this booking.</p>
    """)
    |> text_body("""
    Hi #{user.name},

    #{client.name} has requested a booking:
    Service: #{service}
    When: #{dt}
    Address: #{booking.address}
    #{if booking.notes && booking.notes != "", do: "Notes: #{booking.notes}\n", else: ""}

    Log in to Skill Bridge to confirm or reject this booking.
    """)
  end

  def booking_confirmed(booking) do
    client = booking.user
    profile = booking.skilled_profile
    provider = profile.user.name
    service = profile.skill_category.name
    dt = format_dt(booking.scheduled_at)

    new()
    |> to({client.name, client.email})
    |> from(@from)
    |> subject("Booking confirmed: #{service} on #{dt}")
    |> html_body("""
    <p>Hi #{client.name},</p>
    <p>Your booking has been <strong>confirmed</strong> by #{provider}.</p>
    <ul>
      <li><strong>Service:</strong> #{service}</li>
      <li><strong>When:</strong> #{dt}</li>
      <li><strong>Address:</strong> #{booking.address}</li>
    </ul>
    """)
    |> text_body("""
    Hi #{client.name},

    Your booking has been confirmed by #{provider}.
    Service: #{service}
    When: #{dt}
    Address: #{booking.address}
    """)
  end

  def booking_cancelled(booking, cancelled_by) do
    profile = booking.skilled_profile
    provider = profile.user
    client = booking.user
    service = profile.skill_category.name
    dt = format_dt(booking.scheduled_at)

    {to_user, msg} =
      case cancelled_by do
        :user ->
          {provider, "#{client.name} has cancelled their booking for #{service} on #{dt}."}

        :skilled_person ->
          {client, "#{provider.name} has cancelled the booking for #{service} on #{dt}."}
      end

    new()
    |> to({to_user.name, to_user.email})
    |> from(@from)
    |> subject("Booking cancelled: #{service} on #{dt}")
    |> html_body("""
    <p>Hi #{to_user.name},</p>
    <p>#{msg}</p>
    """)
    |> text_body("Hi #{to_user.name},\n\n#{msg}\n")
  end

  def booking_completed(booking) do
    client = booking.user
    profile = booking.skilled_profile
    provider = profile.user.name
    service = profile.skill_category.name
    dt = format_dt(booking.scheduled_at)

    new()
    |> to({client.name, client.email})
    |> from(@from)
    |> subject("Booking completed: #{service} on #{dt}")
    |> html_body("""
    <p>Hi #{client.name},</p>
    <p>Your booking with <strong>#{provider}</strong> has been marked <strong>completed</strong>. Thank you for using Skill Bridge!</p>
    <ul>
      <li><strong>Service:</strong> #{service}</li>
      <li><strong>When:</strong> #{dt}</li>
      <li><strong>Address:</strong> #{booking.address}</li>
    </ul>
    <p>We'd love to hear your feedback — please leave a review for #{provider}.</p>
    """)
    |> text_body("""
    Hi #{client.name},

    Your booking with #{provider} has been marked completed. Thank you for using Skill Bridge!
    Service: #{service}
    When: #{dt}
    Address: #{booking.address}

    We'd love to hear your feedback — please leave a review for #{provider}.
    """)
  end

  defp format_dt(nil), do: "—"
  defp format_dt(dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M UTC")
end
