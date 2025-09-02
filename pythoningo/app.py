import tkinter as tk
import json
import random

class App(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("English-Polish Flashcards")
        self.geometry("800x600")

        with open("dictionary.json", "r", encoding="utf-8") as f:
            self.data = json.load(f)
        
        self.all_items = self.data["entries"]
        self.current_item = None
        self.correct_answer = ""

        self.question_label = tk.Label(self, text="", wraplength=780, font=("Helvetica", 16))
        self.question_label.pack(pady=20)

        self.example_frame = tk.Frame(self)
        self.example_frame.pack(pady=10)

        self.example_label = tk.Label(self.example_frame, text="", wraplength=680, font=("Helvetica", 12, "italic"), justify=tk.LEFT)
        self.example_label.pack(side=tk.LEFT, fill=tk.X, expand=True)

        self.show_example_button = tk.Button(self.example_frame, text="Show Example", command=self.show_example)
        self.show_example_button.pack(side=tk.LEFT, padx=10)

        self.answer_buttons_frame = tk.Frame(self)
        self.answer_buttons_frame.pack(pady=20)
        self.answer_buttons = []
        for i in range(4):
            button = tk.Button(self.answer_buttons_frame, text="", width=30, command=lambda i=i: self.check_answer(i))
            button.grid(row=i//2, column=i%2, padx=5, pady=5)
            self.answer_buttons.append(button)

        self.feedback_label = tk.Label(self, text="", font=("Helvetica", 14, "bold"))
        self.feedback_label.pack(pady=10)

        self.translation_label = tk.Label(self, text="", wraplength=780, font=("Helvetica", 12))
        self.translation_label.pack(pady=10)

        # Frame for action buttons
        self.action_button_frame = tk.Frame(self)
        self.action_button_frame.pack(pady=20)

        self.next_button = tk.Button(self.action_button_frame, text="Next Question", command=self.next_question)
        
        self.next_question()

    def show_example(self):
        self.example_label.config(text=f'e.g., "{self.current_item["example_english"]}"')
        self.show_example_button.config(state="disabled")

    def next_question(self):
        self.next_button.pack_forget()
        self.show_example_button.config(state="normal")

        self.feedback_label.config(text="")
        self.translation_label.config(text="")
        self.example_label.config(text="")

        self.current_item = random.choice(self.all_items)
        self.correct_answer = self.current_item["polish"]
        
        self.question_label.config(text=self.current_item["english"])

        answers = self.get_random_answers()
        random.shuffle(answers)

        for i, button in enumerate(self.answer_buttons):
            button.config(text=answers[i], state="normal")

    def get_random_answers(self):
        answers = [self.correct_answer]
        while len(answers) < 4:
            random_item = random.choice(self.all_items)
            if random_item["polish"] not in answers:
                answers.append(random_item["polish"])
        return answers

    def check_answer(self, index):
        chosen_answer = self.answer_buttons[index].cget("text")
        if chosen_answer == self.correct_answer:
            self.feedback_label.config(text="Correct!", fg="green")
        else:
            self.feedback_label.config(text=f"Incorrect. Correct was: {self.correct_answer}", fg="red")
        
        if not self.example_label.cget("text"):
            self.show_example()
        
        self.translation_label.config(text=f'Translation: "{self.current_item["example_polish"]}"')

        for button in self.answer_buttons:
            button.config(state="disabled")
        
        self.next_button.pack()

if __name__ == "__main__":
    app = App()
    app.mainloop()
