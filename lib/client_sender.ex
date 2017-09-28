defmodule ClientSender do
  @moduledoc """
  クライアントからサーバへメッセージを送信するプロセス全体のモジュール
  """
  # 入力のタイムアウト時間をmsで指定
  @timeout 120000 # 120 ms * 1000 = 1s

  @doc """
  クライアント側の入力が何らかのコマンドか、チャットを送信しているかを
  判別して、サーバ側に送信
  ## 実装したコマンド一覧
  - ``:help``
    - ヘルプを表示します。
  - ``:exit``
    - クライアントを終了します
  - ``:channel_list``
    - 現在サーバが保持しているチャンネル一覧を表示します
  - ``:now_channel``
    - 現在クライアントが所属しているチャンネルを表示します
  - ``:user_list``
    - 現在所属しているチャンネルのユーザ一覧を表示します
  - ``:user_list arg1``
    - arg1で指定したチャンネルのユーザ一覧を表示します
  - ``:move arg1``
    - クライアントの所属チャンネルをarg1チャンネルに移動します
  - ``:crerate arg1``
    - 新しくarg1というチャンネルを作成し、クライアントのチャンネルをarg1に移動します
  - ``:whisper arg1 arg2``
    - (チャンネル関係なく)arg1ユーザにarg2メッセージを送信します
  - ``:delete arg1``
    - arg1チャンネルに所属するユーザがいない場合arg1チャンネルを削除します
  - ``other``
    - クライアントが現在所属しているチャンネル内に(other)を発言します
  """
  def chat_send(sock, username) do
    # 入力をタイムアウトさせて、接続を継続するか質問
    body = try do
      # IO.getsを並列化して、awaitでタイムアウトを見張る
      Task.async(fn -> IO.gets "\r> " end) |> Task.await(@timeout)
    catch
      # タイムアウトすると :exit,TaskInfoが返ってくるのでパターンマッチ
      :exit,_ ->
        case IO.gets "\rDo you want to exit? (y or other) " do
          "y\n" ->
            ":exit\n"
          _ ->
            ":nop\n"
        end
    end

    cond do
      # 何もしない
      ":nop\n" == body -> # 何もしない
        chat_send(sock, username)

      # helpを表示
      ":help\n" == body ->
        data = "%{event: \"help\"}"
        :gen_tcp.send(sock, data)
        chat_send(sock, username)

      # クライアントを終了する
      ":exit\n" == body ->
        data = "%{event: \"exit\", username: \"#{username}\"}"
        :gen_tcp.send(sock, data)

      # サーバが保持しているチャンネルのリストを表示
      ":channel_list\n"  == body ->
        data = "%{event: \"channel_list\"}"
        :gen_tcp.send(sock, data)
        chat_send(sock, username)

      # 現在クライアントが参加しているチャンネルを表示
      ":now_channel\n"  == body ->
        data = "%{event: \"now_channel\"}"
        :gen_tcp.send(sock, data)
        chat_send(sock, username)

      # 現在クライアントが所属しているチャンネルのユーザリストを表示
      ":user_list\n" == body ->
        data = "%{event: \"user_list_pid\"}"
        :gen_tcp.send(sock, data)
        chat_send(sock, username)

      # 指定したチャンネルのユーザリストを表示
      Regex.match?(~r/^:user_list\s+.+/, body) ->
        channel = Regex.run(~r/:user_list\s+(.+)\n/, body) |> Enum.at(1)
        data = "%{event: \"user_list_channel\", channel: \"#{channel}\"}"
        :gen_tcp.send(sock, data)
        chat_send(sock, username)

        # チャンネルを指定したところへ移動
      Regex.match?(~r/^:move\s+.+/, body) ->
        channel = Regex.run(~r/:move\s+(.+)\n/, body) |> Enum.at(1)
        data = "%{event: \"move\", username: \"#{username}\", channel: \"#{channel}\"}"
        :gen_tcp.send(sock, data)
        chat_send(sock, username)

        # チャンネルを新しく作成して作成したユーザをそのチャンネルへ移動
      Regex.match?(~r/^:create\s+.+/, body) ->
        channel = Regex.run(~r/:create\s+(.+)\n/, body) |> Enum.at(1)
        data = "%{event: \"create\", username: \"#{username}\", channel: \"#{channel}\"}"
        :gen_tcp.send(sock, data)
        chat_send(sock, username)

        # チャンネルを指定したところへ移動
      Regex.match?(~r/^:delete\s+.+/, body) ->
        channel = Regex.run(~r/:delete\s+(.+)\n/, body) |> Enum.at(1)
        data = "%{event: \"delete\", channel: \"#{channel}\"}"
        :gen_tcp.send(sock, data)
        chat_send(sock, username)

        # 指定した(ユーザ名)ユーザにメッセージを送信(format: /whisper\s+#{username}\s+#{body})
      Regex.match?(~r/^:whisper\s+.+?\s+.+/, body) ->
        info = Regex.run(~r/:whisper\s+(.+?)\s+(.+)/, body)
        opponent = info |> Enum.at(1)
        body = info |> Enum.at(2)
        data = "%{event: \"whisper\", username: \"#{username}\", opponent: \"#{opponent}\", body: \"#{"#{body}\n"}\"}"
        :gen_tcp.send(sock, data)
        chat_send(sock, username)

        # 指定のコマンドが無い場合、チャットに発言する
      true ->
        data = "%{event: \"say\", username: \"#{username}\", body: \"#{body}\"}"
        :gen_tcp.send(sock, data)
        chat_send(sock, username)
    end
  end
end
