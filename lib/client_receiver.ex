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
  サーバ側からデータが送信されてきたら問答無用で出力する
  \\rで> をごまかしている
  """
  def chat_recv(sock) do
    {:ok, body} = :gen_tcp.recv(sock, 0)
    # username with body and remove last elem from message
    IO.puts "\r#{body |> remove_last}"
    chat_recv(sock)
  end
end
