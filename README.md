# README

This README would normally document whatever steps are necessary to get the
application up and running.

# Các bước setup Docker và môi trường để chạy Ruby on Rails và MySQL:

- Tạo file Dockerfile và viết các lệnh để tải Ruby on Rails về trong máy ảo Linux của Docker (Do phiên bản 6.0.0 đã cũ nên phải thêm 2 lệnh ở dưới để tải bản lưu trữ về)
RUN echo "deb http://archive.debian.org/debian buster main" > /etc/apt/sources.list && \
    echo "Acquire::Check-Valid-Until \"false\";" > /etc/apt/apt.conf.d/10no--check-valid-until
- Tạo file docker-compose.yml để setup cho database nhằm giúp cho Docker khởi tạo 2 máy ảo chạy song song cùng lúc, 1 máy chạy môi trường Ruby on Rails và 1 máy chạy MySQL
- Tạo file Gemfile với mục đích khai báo các phiên bản trong Rails mà mình muốn tải về, ở đây là Rails 6.0.0
- Trong file Gemfile, thêm gem 'concurrent-ruby', '1.3.4' cùng gem 'ffi', '1.15.5' vào cuối cùng để sửa lỗi xung đột phiên bản của Rails 6.
- Tạo file Gemfile.lock rỗng để sau khi khởi tạo nó sẽ lưu các phiên bản và thư viện đã tải về trong đó
- Tạo file entrypoint.sh để tự động xóa các file pid khi Docker build fail

# Sau khi tạo và viết các lệnh, chạy lần lượt các câu lẹnh sau để setup:
- docker-compose build
- docker-compose run --no-deps web rails new . --force --database=mysql
- docker-compose build
- docker-compose run web rails db:create
- docker-compose run web rails db:migrate
# Lưu ý
- Nếu bị lỗi ở file entrypoint.sh thì bấ chuyển CRLF sang LF tại file đó