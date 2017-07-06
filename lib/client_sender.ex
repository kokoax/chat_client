defmodule ClientSender do
  @moduledoc """
  クライアントからサーバへメッセージを送信するプロセス全体のモジュール
  """
  require Logger

  @doc """
  クライアント側の入力が何らかのコマンドか、チャットを送信しているかを
  判別して、サーバ側に送信
  """
  def chat_send(sock, username) do
    body = IO.gets "> "
    cond do
      "/exit\n" == body -> # クライアントを終了する
        data = "%{event: \"exit\", username: \"#{username}\"}"
        :gen_tcp.send(sock, data)
      "/channel_list\n"  == body -> # サーバが保持しているチャンネルのリストを表示
        data = "%{event: \"channel_list\"}"
        :gen_tcp.send(sock, data)
        chat_send(sock, username)
      "/now_channel\n"  == body -> # 現在クライアントが参加しているチャンネルを表示
        data = "%{event: \"now_channel\"}"
        :gen_tcp.send(sock, data)
        chat_send(sock, username)
      "/user_list\n" == body ->
        data = "%{event: \"user_list\"}"
        :gen_tcp.send(sock, data)
        chat_send(sock, username)
      Regex.match?(~r/^\/move.+/, body) ->  # チャンネルを指定したところへ移動
        data = "%{event: \"move\", username: \"#{username}\", channel: \"#{Regex.run(~r/\/move\s+(.+)\n/, body) |> Enum.at(1)}\"}"
        :gen_tcp.send(sock, data)
        chat_send(sock, username)
      Regex.match?(~r/^\/whisper.+/, body) -> # 指定した(ユーザ名)ユーザにメッセージを送信(format: /whisper\s+#{username}\s+#{body})
        info = Regex.run(~r/\/whisper\s+(.+?)\s+(.+)/, body)
        opponent = info |> Enum.at(1)
        body = info |> Enum.at(2)
        data = "%{event: \"whisper\", username: \"#{username}\", opponent: \"#{opponent}\", body: \"#{"#{body}\n"}\"}"
        :gen_tcp.send(sock, data)
        chat_send(sock, username)
      true -> # 指定のコマンドが無い場合、チャットに発言する
        data = "%{event: \"say\", username: \"#{username}\", body: \"#{body}\"}"
        :gen_tcp.send(sock, data)
        chat_send(sock, username)
    end
  end
end
