defmodule Dagger.ModuleFunctionTest do
  use Dagger.Case, async: true
  use Mneme

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

    auto_assert(
      """
      {
          "test": {
              "hello": "hello"
          }
      }
      """ <-
        query(mod, """
        {
          test {
            hello
          }
        }
        """)
    )

    auto_assert(
      """
      {
          "test": {
              "echo": "world"
          }
      }
      """ <-
        query(mod, """
        {
          test {
            echo(msg: "world")
          }
        }
        """)
    )

    auto_assert(
      """
      {
          "test": {
              "echoList": "a+b+c"
          }
      }
      """ <-
        query(mod, """
        {
          test {
            echoList(msg: ["a", "b", "c"])
          }
        }
        """)
    )

    auto_assert(
      """
      {
          "test": {
              "echoList2": "a+b+c"
          }
      }
      """ <-
        query(mod, """
        {
          test {
            echoList2(msg: ["a", "b", "c"])
          }
        }
        """)
    )
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

    auto_assert(
      """
      {
          "test": {
              "read": "bar"
          }
      }
      """ <-
        query(mod, """
        {
          test {
            read(dir: "#{dir_id}")
          }
        }
        """)
    )
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

    auto_assert(
      """
      {
          "test": {
              "hello": "Hello, john"
          }
      }
      """ <-
        query(mod, """
        {
          test {
            hello(name: "john")
          }
        }
        """)
    )

    auto_assert(
      """
      {
          "test": {
              "hello": "Please give me a name. 😊"
          }
      }
      """ <-
        query(mod, """
        {
          test {
            hello(name: null)
          }
        }
        """)
    )

    auto_assert(
      """
      {
          "test": {
              "hello": "Please give me a name. 😊"
          }
      }
      """ <-
        query(mod, """
        {
          test {
            hello
          }
        }
        """)
    )
  end

  test "context directory", %{dag: dag} do
    mod =
      dag
      |> dagger_cli_base()
      |> dagger_init()
      |> dagger_with_source("test/lib/test.ex", """
      defmodule Test do
        use Dagger.Mod.Object, name: "Test"

        defn entries(dir: {Dagger.Directory.t() | nil, default_path: "/", ignore: ["dagger_sdk"]}) :: [String.t()] do
          dir
          |> Dagger.Directory.entries()
        end

        defn entries_no_ignore(dir: {Dagger.Directory.t() | nil, default_path: "/"}) :: [String.t()] do
          dir
          |> Dagger.Directory.entries()
        end
      end
      """)

    auto_assert(
      """
      {
          "test": {
              "entries": [
                  ".gitattributes",
                  ".gitignore",
                  "LICENSE",
                  "dagger.json",
                  "test"
              ]
          }
      }
      """ <-
        query(mod, """
        {
          test {
            entries
          }
        }
        """)
    )

    auto_assert(
      """
      {
          "test": {
              "entriesNoIgnore": [
                  ".gitattributes",
                  ".gitignore",
                  "LICENSE",
                  "dagger.json",
                  "dagger_sdk",
                  "test"
              ]
          }
      }
      """ <-
        query(mod, """
        {
          test {
            entriesNoIgnore
          }
        }
        """)
    )
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
