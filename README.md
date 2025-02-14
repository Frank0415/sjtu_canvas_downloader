# sjtu_canvas_downloader

A bash script to download course files from SJTU canvas

一个用于下载canvas课程文件的bash脚本。

## 使用方法

1. 需要安装`jq`和`curl`。

### Mac

```sh
brew install jq curl
```

### Ubuntu

```sh
sudo apt-get update
sudo apt-get install jq curl
```

### Arch Linux

```sh
sudo pacman -S jq curl
```
2. 将repo clone到本地

在`main.sh`同文件夹里应创建：

- `token.txt`，内容为你的 canvas token
- `courses.txt`，内容为你要下载的课程
  - 第一行有一个数字，表示课程数量
  - 之后第一行是课程名，第二行是课程 id，共有课程数量*2行
  - 对于每门课创建一个课程名字的文件夹，在文件夹里面下载文件
- `path.txt`，内容为你要下载的文件的路径($HOME 的相对路径)
- 可以查看`example`文件夹里的例子

