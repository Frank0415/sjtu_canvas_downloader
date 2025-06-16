#!/bin/bash

# Canvas API 配置
CUR_PATH="$(dirname "$0")"
CANVAS_URL="https://oc.sjtu.edu.cn"
CANVAS_API_URL="$CANVAS_URL/api/v1"
API_KEY="$(<"$CUR_PATH/token.txt")"  # 从与脚本相同文件夹中的 token.txt 文件中读取 API 密钥

# 下载配置
DOWNLOAD_FOLDER="$(<"$CUR_PATH/path.txt")"  # 下载文件存储路径
SYNC_ON=true

function usage() {
    echo "用法: $0 [-f|--false] [-t|--true]"
    echo "  -f, --false   禁用同步模式（下载所有文件）"
    echo "  -t, --true    启用同步模式（跳过已下载的文件）"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--false)
            SYNC_ON=false
            shift
            ;;
        -t|--true)
            SYNC_ON=true
            shift
            ;;
        *)
            usage
            SYNC_ON=true
            shift
            ;;
    esac
    shift
done
# read -p "是否启用同步模式（跳过已下载的文件）默认启用？(y/n): " sync_choice
# if [ "$sync_choice" = "n" ]; then
#     SYNC_ON=false
# else
#     SYNC_ON=true
# fi

# 检查 API 密钥
if [ -z "$API_KEY" ]; then
    echo "错误：未提供 Canvas API 密钥。请确保 token.txt 文件存在并包含有效的 API 密钥。"
    exit 1
fi

# 创建下载目录
mkdir -p "$DOWNLOAD_FOLDER"

# 获取课程文件夹列表
get_course_folders() {
    local course_id=$1
    echo "正在获取课程 $course_id 的文件夹列表..."
    local url="$CANVAS_API_URL/courses/$course_id/folders?per_page=100"
    while [ -n "$url" ]; do
        response=$(curl -s -H "Authorization: Bearer $API_KEY" "$url")
        echo "$response" | jq -r '.[].id'
        url=$(echo "$response" | jq -r '.links.next' | sed 's/&per_page=[0-9]*//')
    done
}

# 获取文件夹中的文件列表
get_files_in_folder() {
    local folder_id=$1
    echo "正在获取文件夹 $folder_id 中的文件列表..."
    local url="$CANVAS_API_URL/folders/$folder_id/files?per_page=100"
    while [ -n "$url" ]; do
        response=$(curl -s -H "Authorization: Bearer $API_KEY" "$url")
        echo "$response" | jq -r '.[] | "\(.id) \(.display_name)"'
        url=$(echo "$response" | jq -r '.links.next' | sed 's/&per_page=[0-9]*//')
    done
}

# 下载文件
download_file() {
    local file_id=$1
    local file_name=$2
    local folder_name=$3

    # 获取文件下载 URL
    echo "正在获取文件 $file_name 的下载链接..."
    file_url=$(curl -s -H "Authorization: Bearer $API_KEY" "$CANVAS_API_URL/files/$file_id" | jq -r '.url')
    if [ -z "$file_url" ]; then
        echo "错误：无法获取文件 $file_name 的下载链接。"
        return
    fi

    # 创建文件夹并下载文件
    mkdir -p "$DOWNLOAD_FOLDER/$folder_name"
    echo "正在下载文件 $file_name 到 $DOWNLOAD_FOLDER/$folder_name..."
    curl -L -H "Authorization: Bearer $API_KEY" "$file_url" -o "$DOWNLOAD_FOLDER/$folder_name/$file_name"

    # 检查下载是否成功
    if [ $? -eq 0 ] && [ -s "$DOWNLOAD_FOLDER/$folder_name/$file_name" ]; then
        echo "下载成功：$file_name"
    else
        echo "下载失败：$file_name"
        rm -f "$DOWNLOAD_FOLDER/$folder_name/$file_name"  # 清理空文件
    fi
}

# 获取本地已下载文件列表
get_current_files() {
    find "$DOWNLOAD_FOLDER" -type f | sed "s|$DOWNLOAD_FOLDER/||"
}

# 删除空文件夹
clean_empty_folders() {
    local dir=$1
    echo "正在清理空文件夹$DOWNLOAD_FOLDER/$dir..."
    find "$DOWNLOAD_FOLDER/$dir" -type d -empty -delete
    echo "空文件夹清理完成。"
}

# 同步文件
sync_files() {
    echo "开始同步文件..."
    current_files=$(get_current_files)
    new_files_count=0

    # 读取 courses.txt 文件
    if [ ! -f "$(dirname "$0")/courses.txt" ]; then
        echo "错误：courses.txt 文件不存在。"
        exit 1
    fi

    # 读取课程数量
    read -r num_courses < "$(dirname "$0")/courses.txt"
    echo "Number of courses: $num_courses"

    # Skip the first line (number of courses)
    tail -n +2 "$(dirname "$0")/courses.txt" > temp_courses.txt

    # Read course information and create directories
    for ((i = 1; i <= num_courses; i++)); do
        course_name=$(sed -n "$((2 * i - 1))p" temp_courses.txt)
        course_id=$(sed -n "$((2 * i))p" temp_courses.txt)
        echo "Processing course: $course_name (ID: $course_id)"

        # Create folder for each course
        course_folder="$DOWNLOAD_FOLDER/$course_name"
        mkdir -p "$course_folder"

        # Iterate through course folders
        for folder_id in $(get_course_folders "$course_id"); do
            folder_name=$(curl -s -H "Authorization: Bearer $API_KEY" "$CANVAS_API_URL/folders/$folder_id" | jq -r '.name')
            if [ -z "$folder_name" ] || [ "$folder_name" = "null" ]; then
                continue
            fi
            echo "Processing folder: $folder_name"

            # Iterate through files in folder
            while read -r file_id file_name; do
            if [ -z "$file_id" ] || [ -z "$file_name" ] || [ "$file_name" = "null" ] || [ "$folder_name" = "null" ]; then
                continue
            fi

            # Check if file is already downloaded
            if [ "$SYNC_ON" = true ] && echo "$current_files" | grep -q "$course_name/$folder_name/$file_name"; then
                echo "File already exists, skipping: $course_name/$folder_name/$file_name"
            else
                download_file "$file_id" "$file_name" "$course_name/$folder_name"
                new_files_count=$((new_files_count + 1))
            fi
            done < <(get_files_in_folder "$folder_id")
        done

        clean_empty_folders "$course_name"

    done

    # Clean up temporary file
    rm temp_courses.txt

    echo "Sync complete. Downloaded $new_files_count new files."
}

# 运行同步
sync_files
