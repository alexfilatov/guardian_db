defmodule Guardian.DB.Token do
  @moduledoc """
  A very simple model for storing tokens generated by `Guardian`.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, only: [where: 3]

  alias Guardian.DB.Token

  @primary_key {:jti, :string, autogenerate: false}
  @required_fields ~w(jti aud)a
  @allowed_fields ~w(jti typ aud iss sub exp jwt claims)a

  schema "virtual: token" do
    field(:typ, :string)
    field(:aud, :string)
    field(:iss, :string)
    field(:sub, :string)
    field(:exp, :integer)
    field(:jwt, :string)
    field(:claims, :map)

    timestamps()
  end

  @doc """
  Find one token by matching jti and aud.
  """
  def find_by_claims(claims) do
    adapter().one(claims, prefix: prefix())
  end

  @doc """
  Create a new token based on the JWT and decoded claims.
  """
  def create(claims, jwt) do
    prepared_claims =
      claims
      |> Map.put("jwt", jwt)
      |> Map.put("claims", claims)

    %Token{}
    |> Ecto.put_meta(source: schema_name())
    |> Ecto.put_meta(prefix: prefix())
    |> cast(prepared_claims, @allowed_fields)
    |> validate_required(@required_fields)
    |> adapter().insert(prefix: prefix())
  end

  @doc """
  Purge any tokens that are expired. This should be done periodically to keep
  your DB table clean of clutter.
  """
  def purge_expired_tokens do
    timestamp = Guardian.timestamp()

    adapter().purge_expired_tokens(timestamp, prefix: prefix())
  end

  @doc false
  def destroy_by_sub(sub) do
    adapter().delete_by_sub(sub, prefix: prefix())
  end

  @doc false
  def query_schema do
    {schema_name(), Token}
  end

  @doc false
  def schema_name do
    :guardian
    |> Application.fetch_env!(Guardian.DB)
    |> Keyword.get(:schema_name, "guardian_tokens")
  end

  @doc false
  def prefix do
    :guardian
    |> Application.fetch_env!(Guardian.DB)
    |> Keyword.get(:prefix, nil)
  end

  @doc false
  def destroy_token(nil, claims, jwt), do: {:ok, {claims, jwt}}

  def destroy_token(model, claims, jwt) do
    case adapter().delete(model, prefix: prefix()) do
      {:error, _} -> {:error, :could_not_revoke_token}
      nil -> {:error, :could_not_revoke_token}
      _ -> {:ok, {claims, jwt}}
    end
  end

  defp adapter do
    :guardian
    |> Application.fetch_env!(Guardian.DB)
    |> Keyword.get(:adapter, Guardian.DB.EctoAdapter)
  end
end
