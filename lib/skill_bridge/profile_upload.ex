defmodule SkillBridge.ProfileUpload do
  @moduledoc """
  Saves profile photos to priv/static/uploads/profiles/ and returns a short
  public path ("/uploads/profiles/...") served by Plug.Static.

  Two entry points:
    - save_from_temp/2  — for LiveView file uploads (already on disk as a temp file)
    - save_from_base64/1 — for pasted data-URLs (base64-encoded image in memory)

  Neither stores image data in the database. Only the short path is persisted.
  """

  @max_size 5 * 1024 * 1024
  @allowed_exts ~w(.jpg .jpeg .png .webp)

  @doc """
  Copies a LiveView-uploaded temp file into static storage.
  Returns `{:ok, "/uploads/profiles/<uuid>.<ext>"}` or `{:error, reason}`.
  """
  def save_from_temp(source_path, client_name) when is_binary(source_path) do
    ext = client_name |> Path.extname() |> String.downcase()

    with true <- ext in @allowed_exts,
         {:ok, data} <- File.read(source_path),
         true <- byte_size(data) <= @max_size,
         true <- magic_matches?(data, ext) do
      write_to_disk(data, ext)
    else
      false -> {:error, :invalid_type}
      {:error, _} -> {:error, :read_failed}
      _ -> {:error, :invalid_file}
    end
  end

  @doc """
  Decodes a data-URL (e.g. "data:image/jpeg;base64,...") and saves it to disk.
  Returns `{:ok, "/uploads/profiles/<uuid>.<ext>"}` or `{:error, reason}`.
  """
  def save_from_base64("data:" <> rest) do
    with [meta, b64] <- String.split(rest, ",", parts: 2),
         ext <- mime_to_ext(meta),
         true <- ext in @allowed_exts,
         {:ok, data} <- Base.decode64(b64, ignore: :whitespace),
         true <- byte_size(data) <= @max_size,
         true <- magic_matches?(data, ext) do
      write_to_disk(data, ext)
    else
      _ -> {:error, :invalid_base64}
    end
  end

  def save_from_base64(_), do: {:error, :not_a_data_url}

  # ── Shared helpers ─────────────────────────────────────────────────────────

  defp write_to_disk(data, ext) do
    dir = uploads_dir()
    :ok = File.mkdir_p(dir)
    filename = "#{Ecto.UUID.generate()}#{ext}"
    dest = Path.join(dir, filename)

    case File.write(dest, data) do
      :ok -> {:ok, "/uploads/profiles/#{filename}"}
      {:error, _} -> {:error, :write_failed}
    end
  end

  def uploads_dir do
    Application.app_dir(:skill_bridge, "priv/static/uploads/profiles")
  end

  defp mime_to_ext(meta) do
    cond do
      String.contains?(meta, "image/jpeg") -> ".jpg"
      String.contains?(meta, "image/jpg") -> ".jpg"
      String.contains?(meta, "image/png") -> ".png"
      String.contains?(meta, "image/webp") -> ".webp"
      true -> ""
    end
  end

  # Magic-byte validation — never trust the client extension alone
  defp magic_matches?(<<0xFF, 0xD8, 0xFF, _::binary>>, ext) when ext in [".jpg", ".jpeg"],
    do: true

  defp magic_matches?(<<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, _::binary>>, ".png"),
    do: true

  defp magic_matches?(<<"RIFF", _::binary-size(4), "WEBP", _::binary>>, ".webp"), do: true
  defp magic_matches?(_, _), do: false
end
