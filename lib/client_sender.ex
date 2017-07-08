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
        case IO.gets "\rAre you exit? (y or other) " do
          "y\n" ->
            ":exit\n"
          _ ->
            ":nop\n"
        end
    end

    cond do
      ":nop\n" == body -> # 何もしない
        chat_send(sock, username)
      ":exit\n" == body -> # クライアントを終了する
        data = "%{event: \"exit\", username: \"#{username}\"}"
        :gen_tcp.send(sock, data)
      ":channel_list\n"  == body -> # サーバが保持しているチャンネルのリストを表示
        data = "%{event: \"channel_list\"}"
        :gen_tcp.send(sock, data)
        chat_send(sock, username)
      ":now_channel\n"  == body -> # 現在クライアントが参加しているチャンネルを表示
        data = "%{event: \"now_channel\"}"
        :gen_tcp.send(sock, data)
        chat_send(sock, username)
      ":user_list\n" == body -> # 現在クライアントが所属しているチャンネルのユーザリストを表示
        data = "%{event: \"user_list_pid\"}"
        :gen_tcp.send(sock, data)
        chat_send(sock, username)
      Regex.match?(~r/^:user_list.+/, body) -> # 指定したチャンネルのユーザリストを表示
        data = "%{event: \"user_list_channel\", channel: \"#{Regex.run(~r/:user_list\s+(.+)\n/, body) |> Enum.at(1)}\"}"
        :gen_tcp.send(sock, data)
        chat_send(sock, username)
      Regex.match?(~r/^:move.+/, body) ->  # チャンネルを指定したところへ移動
        data = "%{event: \"move\", username: \"#{username}\", channel: \"#{Regex.run(~r/:move\s+(.+)\n/, body) |> Enum.at(1)}\"}"
        :gen_tcp.send(sock, data)
        chat_send(sock, username)
      Regex.match?(~r/^:create.+/, body) ->  # チャンネルを新しく作成して作成したユーザをそのチャンネルへ移動
        data = "%{event: \"create\", username: \"#{username}\", channel: \"#{Regex.run(~r/:create\s+(.+)\n/, body) |> Enum.at(1)}\"}"
        :gen_tcp.send(sock, data)
        chat_send(sock, username)
      Regex.match?(~r/^:delete.+/, body) ->  # チャンネルを指定したところへ移動
        data = "%{event: \"delete\", channel: \"#{Regex.run(~r/:delete\s+(.+)\n/, body) |> Enum.at(1)}\"}"
        :gen_tcp.send(sock, data)
        chat_send(sock, username)
      Regex.match?(~r/^:whisper.+/, body) -> # 指定した(ユーザ名)ユーザにメッセージを送信(format: /whisper\s+#{username}\s+#{body})
        info = Regex.run(~r/:whisper\s+(.+?)\s+(.+)/, body)
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
