defmodule ChatClient do
  @moduledoc """
  - CUIチャットシステムのクライアントサイドの実装
  ## Arguments
  - ``--domain, -d``
    - サーバの起動しているドメインを指定
  - ``--port, -p``
    - サーバの利用しているポート番号を指定
  - ``--username -u``
    - チャットで利用するユーザ名を指定
  ## Usage
  - すべての引数が無いと動きません
  - ``$ ./chat_client --domain "localhost" --port 1600 --username Yoshitomo``
  - ``$ ./chat_client -d "127.0.0.1" -p 65535 -u yoshitune``
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
  サーバと接続したら、サーバからの受信とサーバへの送信のプロセスを並列化して実行
  """
  def main_process(sock, username) do
    :gen_tcp.send(sock, username)  # コネクションを繋いだら、usernameを送信し、サーバ側に登録する
    task = Task.async(fn -> ClientReceiver.chat_recv(sock) end)  # サーバから送られてくるメッセージを取得表示する部分を並列化
    # sockがこのプロセス(loop)に所有権があると、sockをcloseした時、chat_in側も落ちてしまうので、chat_recvのプロセスに所有権を
    # 移動しておいて、sockがcloseしても、とりあえず、エラーにならないようにしている
    :ok = :gen_tcp.controlling_process(sock, task.pid)

    # 一定時間入力がないと確認する
    # Task.async(fn -> chat_in(sock, username) end)
    ClientSender.chat_send(sock, username)
    # TODO: TimeOut
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
  def do_process([username, port, domain]) do
    # '#{domain}'はドメインは文字配列で渡さないとエラーになるので
    # ''内に文字列を展開している
    sock = connect('#{domain}', port)
    main_process(sock, username)
  end

  @doc """
  プログラムの引数をパースしてそれに応じて処理を振り分ける
  """
  def parse_args(argv) do
    {options,_,_} = argv |> OptionParser.parse(
      switches: [username: :string, port: :integer, domain: :string],
      aliases:  [u: :username, p: :port, d: :domain],
    )
    # keyword listだと順番が保持され、面倒なのでMapでpattern match
    case options |> Enum.into(%{}) do
      %{domain: domain, port: port, username: username} ->
        [username, port, domain]
      %{port: port, username: username} ->
        [username, port, @def_domain]
      %{domain: domain, username: username} ->
        [username, @def_port, domain]
      %{username: username} ->
        [username, @def_port, @def_domain]
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
