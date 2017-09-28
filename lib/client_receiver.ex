defmodule ClientReceiver do
  @moduledoc """
  サーバからメッセージを受信するプロセス全体のモジュール
  """

  @doc """
  サーバ側から送られてくるデータの最後には改行を付ける
  ようにしているので、クライアント側で改行を削除している
  """
  def remove_last(str) do
    str
    |> String.slice(0,(str|> String.length)-1)
  end

  @doc """
  クライアントからのメッセージは、elixirのMapというデータ構造を文字列にしたもの
  を送信するので、受信したらそのままevalすることで、データを取り出すことができる
  """
  def eval(str) do
    {data, _} = Code.eval_string(str)
    data
  end

  @doc """
  サーバ側からデータが送信されてきたら、eventを解析して
  処理を振り分けている。
  \\rで> をごまかしている
  """
  def chat_recv(sock) do
    data = try do
      {:ok, data} = :gen_tcp.recv(sock, 0)
      data |> IO.inspect
      data |> eval
    rescue
      # 想定外のdataが投げられてくるときがあるので、rescueしてコネクションをclose
      e in MatchError ->
        IO.warn "MatchError: Maybe unxpected connection break."
        %{event: "error", message: "data is exeption.\n"}
    end

    case data.event do
      "message" ->
        IO.puts "\r#{data.message |> remove_last}"
        chat_recv(sock)

      "error" ->
        IO.puts "\r#{data.message |> remove_last}"

      "exit" ->
        IO.puts "\r#{data.message |> remove_last}"
    end
  end
end
