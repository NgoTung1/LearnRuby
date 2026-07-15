class TaskController < ApplicationController
    def index
        @tasks = [
            {id: 1, title: "Thức dậy", description: "Thức vào lúc 6 giờ", status: "pending"},
            {id: 2, title: "Tập thể dục", description: "Tập 100 bài tâp thể dục", status: "completed"}
        ] 
    end
end