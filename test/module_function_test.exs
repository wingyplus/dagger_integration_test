defmodule Dagger.ModuleFunctionTest do
  use Dagger.Case, async: true

  import Dagger.TestHelper

  test "signatures", %{dag: dag} do
    mod =
      dag
      |> dagger_cli_base()
      |> dagger_init()
      |> dagger_with_source("test/lib/test.ex", """
      defmodule Test do
        use Dagger.Mod.Object, name: "Test"

        defn hello() :: String.t(), do: "hello"

        defn echo(msg: String.t()) :: String.t(), do: msg

        defn echo_list(msg: list(String.t())) :: String.t(), do: Enum.join(msg, "+")

        defn echo_list2(msg: [String.t()]) :: String.t(), do: Enum.join(msg, "+")
      end
      """)

    assert query(mod, """
           {
             test {
               hello
             }
           }
           """) ==
             """
             {
                 "test": {
                     "hello": "hello"
                 }
             }
             """

    assert query(mod, """
           {
             test {
               echo(msg: "world")
             }
           }
           """) == """
           {
               "test": {
                   "echo": "world"
               }
           }
           """

    assert query(mod, """
           {
             test {
               echoList(msg: ["a", "b", "c"])
             }
           }
           """) == """
           {
               "test": {
                   "echoList": "a+b+c"
               }
           }
           """

    assert query(mod, """
           {
             test {
               echoList2(msg: ["a", "b", "c"])
             }
           }
           """) == """
           {
               "test": {
                   "echoList2": "a+b+c"
               }
           }
           """
  end

  test "signatures builtin types", %{dag: dag} do
    mod =
      dag
      |> dagger_cli_base()
      |> dagger_init()
      |> dagger_with_source("test/lib/test.ex", """
      defmodule Test do
        use Dagger.Mod.Object, name: "Test"

        defn read(dir: Dagger.Directory.t()) :: String.t() do
          dir
          |> Dagger.Directory.file( "foo")
          |> Dagger.File.contents()
        end
      end
      """)

    assert {:ok, dir_id} =
             dag
             |> Dagger.Client.directory()
             |> Dagger.Directory.with_new_file("foo", "bar")
             |> Dagger.Directory.id()

    assert query(mod, """
           {
             test {
               read(dir: "#{dir_id}")
             }
           }
           """) == """
           {
               "test": {
                   "read": "bar"
               }
           }
           """
  end

  test "optional argument", %{dag: dag} do
    mod =
      dag
      |> dagger_cli_base()
      |> dagger_init()
      |> dagger_with_source("test/lib/test.ex", """
      defmodule Test do
        use Dagger.Mod.Object, name: "Test"

        defn hello(name: String.t() | nil) :: String.t() do
          if is_nil(name) do
            "Please give me a name. 😊"
          else
            "Hello, \#{name}"
          end
        end
      end
      """)

    assert query(mod, """
           {
             test {
               hello(name: "john")
             }
           }
           """) == """
           {
               "test": {
                   "hello": "Hello, john"
               }
           }
           """

    assert query(mod, """
           {
             test {
               hello(name: null)
             }
           }
           """) == """
           {
               "test": {
                   "hello": "Please give me a name. 😊"
               }
           }
           """

    assert query(mod, """
           {
             test {
               hello
             }
           }
           """) == """
           {
               "test": {
                   "hello": "Please give me a name. 😊"
               }
           }
           """
  end

  defp query(mod, q) do
    mod
    |> dagger_query(q)
    |> stdout()
    |> case do
      {:ok, output} -> output
      {:error, exception} -> raise exception
    end
  end
end
