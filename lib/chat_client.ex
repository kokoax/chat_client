defmodule ChatClient do
  @moduledoc """
  - CUIチャットシステムのクライアントサイドの実装
  ## Arguments
  - ``--domain, -d``
    - サーバの起動しているドメインを指定
    - 初期値は "localhost"
  - ``--port, -p``
    - サーバの利用しているポート番号を指定
    - 初期値は 2000
  - ``--username -u``
    - チャットで利用するユーザ名を指定
  - ``--channel, -c``
    - 初期所属チャンネルを指定
    - 初期値は"general"
  ## Usage
  - usernameのみ必須です。
  - ``$ ./chat_client --domain "localhost" --port 1600 --username "Yoshitomo" --channel "new_channel"``
  - ``$ ./chat_client -d "127.0.0.1" -p 65535 -u "yoshitune" -c "new_channel"``
  """
  require ClientSender
  require ClientReceiver

  @def_domain "localhost"
  @def_port   2000

  @doc """
  指定したdomainにportでconnectionを開き、socketを返す
  """
  def connect(domain, port) do
    {:ok, sock} = :gen_tcp.connect(domain, port, [:binary, packet: 0, active: false])
    sock
  end

  @doc """
  コネクションを開いたときにサーバ側にユーザ情報を登録するので
  その情報を文字列で生成する。
  """
  def first_send(username, channel) do
    if channel == nil do
      ~s(%{username: "#{username}", channel: nil})
    else
      ~s(%{username: "#{username}", channel: "#{channel}"})
    end
  end

  @doc """
  サーバと接続したら、サーバからの受信とサーバへの送信のプロセスを並列化して実行
  """
  def main_process(sock, username, channel) do
    # コネクションを繋いだら、usernameを送信し、サーバ側に登録する
    data = first_send(username, channel)
    :gen_tcp.send(sock, data)
    # サーバから送られてくるメッセージを取得表示する部分を並列化
    recv_task = Task.async(fn -> ClientReceiver.chat_recv(sock) end)
    # sockがこのプロセス(loop)に所有権があると、sockをcloseした時、
    # chat_in側も落ちてしまうのでchat_recvのプロセスに所有権を、
    # 移動しておいて、sockがcloseしても、とりあえず、エラーにならないようにしている
    :ok = :gen_tcp.controlling_process(sock, recv_task.pid)

    # 一定時間入力がないと確認する
    send_task = Task.async(fn -> ClientSender.chat_send(sock, username) end)
    recv_task |> Task.await(:infinity)  # サーバからexitを返されるまでwait
    Process.exit(send_task.pid, :kill)
  end

  @doc """
  クライアント実行時の引数の条件を満たしていない場合
  """
  def do_process(nil) do
    IO.warn "Don't enough options"
  end

  @doc """
  サーバとのコネクトを行い、メインのプロセスを実行する
  """
  def do_process([username, channel, port, domain]) do
    # '#{domain}'はドメインは文字配列で渡さないとエラーになるので
    # ''内に文字列を展開している
    sock = connect('#{domain}', port)
    main_process(sock, username, channel)
  end

  @doc """
  プログラムの引数をパースしてそれに応じて処理を振り分ける
  """
  def parse_args(argv) do
    {options,_,_} = argv |> OptionParser.parse(
      switches: [username: :string, channel: :string, port: :integer, domain: :string],
      aliases:  [u: :username, c: :channel, p: :port, d: :domain],
    )
    # keyword listだと順番が保持され、面倒なのでMapでpattern match
    case options |> Enum.into(%{}) do
      %{domain: domain, port: port, username: username} ->
        [username, options[:channel], port, domain]
      %{port: port, username: username} ->
        [username, options[:channel], port, @def_domain]
      %{domain: domain, username: username} ->
        [username, options[:channel], @def_port, domain]
      %{username: username} ->
        [username, options[:channel], @def_port, @def_domain]
      _ ->
        nil
    end
  end

  @doc """
  opts |> parse_args |> do_process
  """
  def main(opts) do
    opts |> parse_args |> do_process
  end
end
