from tkinter import ttk
import os
import shutil
import json
from tkinter import Tk, Label, Entry, Button, filedialog, Frame, StringVar, messagebox, Menu, Toplevel, Canvas
from PIL import Image, ImageTk
from ttkthemes import ThemedTk
import threading

class ImageSelector:
    def __init__(self, master, gridScaleX=3, gridScaleY=3):
        self.master = master
        self.master.title('Image Selector')
        self.master.state('zoomed')  # Maximize the window

        self.style = ttk.Style(master)
        self.style.theme_use('equilux')  # Use the Equilux theme for dark mode

        self.current_theme = StringVar(value=self.style.theme_use())

        self.settings_file = os.path.join(os.path.expanduser('~'), '.picpicker_settings.json')
        self.load_settings()

        self.gridScaleX = self.settings.get('gridScaleX', gridScaleX)
        self.gridScaleY = self.settings.get('gridScaleY', gridScaleY)
        self.images_per_page = self.gridScaleX * self.gridScaleY
        self.current_page = 0
        self.total_pages = 0
        self.all_image_files = []
        self.selected_images = []

        self.source_var = StringVar(value=self.settings.get('source', ''))
        self.destination_var = StringVar(value=self.settings.get('destination', ''))
        self.source_var.trace("w", self.on_directory_change)
        self.destination_var.trace("w", self.on_directory_change)

        self.create_toolbar()
        self.create_layout()

    def create_toolbar(self):
        menubar = Menu(self.master)
        self.master.config(menu=menubar)

        action_menu = Menu(menubar, tearoff=0)
        menubar.add_cascade(label="Actions", menu=action_menu)
        action_menu.add_command(label="Update Grid Size", command=self.update_grid_size)
        action_menu.add_command(label="Set Source Folder", command=lambda: self.browse_directory(self.source_var))
        action_menu.add_command(label="Set Destination Folder", command=lambda: self.browse_directory(self.destination_var))

        view_menu = Menu(menubar, tearoff=0)
        menubar.add_cascade(label="View", menu=view_menu)

        self.themes_menu = Menu(view_menu, tearoff=0)
        view_menu.add_cascade(label="Themes", menu=self.themes_menu)

        self.themes = [
            "adapta","arc", "black", "blue", "clam", "clearlooks", "elegance", "equilux", "itft1", "keramik", "kroc", "plastik",
            "radiance", "scidblue", "scidgreen", "scidgrey", "scidmint", "scidpink", "scidpurple", "scidsand", "smog",
            "ubuntu", "winxpblue", "yaru"
        ]

        for theme in self.themes:
            self.themes_menu.add_radiobutton(label=theme, variable=self.current_theme, value=theme, command=lambda t=theme: self.change_theme(t))

    def change_theme(self, theme):
        self.style.theme_use(theme)
        self.current_theme.set(theme)
        self.save_settings()

    def update_grid_size(self):
        grid_size_window = Toplevel(self.master)
        grid_size_window.title("Update Grid Size")

        ttk.Label(grid_size_window, text="Grid Size X:").grid(row=0, column=0)
        grid_x_entry = ttk.Entry(grid_size_window)
        grid_x_entry.grid(row=0, column=1)

        ttk.Label(grid_size_window, text="Grid Size Y:").grid(row=1, column=0)
        grid_y_entry = ttk.Entry(grid_size_window)
        grid_y_entry.grid(row=1, column=1)

        ttk.Button(grid_size_window, text="Update", command=lambda: self.set_grid_size(grid_x_entry.get(), grid_y_entry.get(), grid_size_window)).grid(row=2, column=0, columnspan=2)

    def set_grid_size(self, x, y, window):
        try:
            self.gridScaleX = int(x)
            self.gridScaleY = int(y)
            self.images_per_page = self.gridScaleX * self.gridScaleY
            self.total_pages = len(self.all_image_files) // self.images_per_page + (1 if len(self.all_image_files) % self.images_per_page else 0)
            self.current_page = 0
            self.display_current_page()
            self.save_settings()
            window.destroy()
        except ValueError:
            messagebox.showerror("Error", "Invalid grid size values.")

    def on_page_number_change(self, *args):
        try:
            page = int(self.page_var.get()) - 1  # Convert to zero-indexed page number
            if 0 <= page < self.total_pages:
                self.current_page = page
                self.display_current_page()
            else:
                self.page_var.set(str(self.current_page + 1))  # Reset to the current page number
        except ValueError:
            self.page_var.set(str(self.current_page + 1))  # Reset if the input is not a valid integer

    def on_directory_change(self, *args):
        directory = self.source_var.get()
        if os.path.isdir(directory):
            self.load_images_from_directory(directory)
            self.save_settings()

    def browse_directory(self, variable):
        directory = filedialog.askdirectory()
        if directory:
            variable.set(directory)
            self.load_images_from_directory(directory)
            self.save_settings()

    def load_images_from_directory(self, directory):
        self.progress_label.config(text=f"Loading images from {directory}")
        self.progress_frame.grid()
        self.progress.start()
        threading.Thread(target=self._load_images_from_directory, args=(directory,)).start()

    def _load_images_from_directory(self, directory):
        self.all_image_files = [f for f in os.listdir(directory) if f.lower().endswith(('.png', '.jpg', '.jpeg', '.gif', '.bmp'))]
        self.total_pages = len(self.all_image_files) // self.images_per_page + (1 if len(self.all_image_files) % self.images_per_page else 0)
        self.current_page = 0
        self.display_current_page()
        self.progress.stop()
        self.progress_frame.grid_remove()

    def display_current_page(self):
        for widget in self.image_frame.winfo_children():
            widget.destroy()

        start_index = self.current_page * self.images_per_page
        end_index = min(start_index + self.images_per_page, len(self.all_image_files))
        for i, filename in enumerate(self.all_image_files[start_index:end_index]):
            row, column = divmod(i, self.gridScaleX)
            self.display_image(filename, row, column)

        self.page_label.config(text=f" of {self.total_pages}")

        # Pre-cache pages 2 before and 2 after the current page
        threading.Thread(target=self.pre_cache_pages).start()

    def pre_cache_pages(self):
        for offset in range(-2, 3):
            if offset == 0:
                continue
            page = self.current_page + offset
            if 0 <= page < self.total_pages:
                self.cache_page(page)

    def cache_page(self, page):
        start_index = page * self.images_per_page
        end_index = min(start_index + self.images_per_page, len(self.all_image_files))
        for i, filename in enumerate(self.all_image_files[start_index:end_index]):
            path = os.path.join(self.source_var.get(), filename)
            img = Image.open(path)
            target_width = self.image_frame.winfo_width() // self.gridScaleX - 10
            target_height = self.image_frame.winfo_height() // self.gridScaleY - 10
            img.thumbnail((target_width, target_height))
            ImageTk.PhotoImage(img)  # Cache the image

    def display_image(self, filename, row, column):
        path = os.path.join(self.source_var.get(), filename)
        img = Image.open(path)

        # Calculate the target size dynamically based on the frame size, grid scale, and the number of images
        num_images = len(self.all_image_files) - self.current_page * self.images_per_page
        grid_x = self.gridScaleX if num_images >= self.gridScaleX else num_images
        grid_y = self.gridScaleY if num_images // self.gridScaleX >= self.gridScaleY else num_images // self.gridScaleX + 1

        target_width = self.image_frame.winfo_width() // grid_x - 10
        target_height = self.image_frame.winfo_height() // grid_y - 10
        img.thumbnail((target_width, target_height))
        photo = ImageTk.PhotoImage(img)

        button = ttk.Button(self.image_frame, image=photo, style='Image.TButton')
        button.image = photo  # Keep a reference!
        button.grid(row=row, column=column, padx=5, pady=5, sticky='nsew')
        button.bind("<Button-1>", lambda e, path=path, button=button: self.toggle_image_selection(path, button))
        button.selected = path in self.selected_images

        if button.selected:
            button.config(style='Highlight.Image.TButton')

        # Center the grid horizontally
        self.image_frame.grid_columnconfigure(column, weight=1)

    def toggle_image_selection(self, path, button):
        if button.selected:
            self.selected_images.remove(path)
            button.config(style='Image.TButton')  # Reset to default style
            button.selected = False
        else:
            self.selected_images.append(path)
            button.config(style='Highlight.Image.TButton')  # Apply the highlight style
            button.selected = True

    def save_selected_images(self):
        destination = self.destination_var.get()
        if not os.path.isdir(destination):
            messagebox.showerror("Error", "Destination directory does not exist.")
            return
        self.progress_label.config(text=f"Saving images to {destination}")
        self.progress_frame.grid()
        self.progress.start()
        threading.Thread(target=self._save_selected_images, args=(destination,)).start()

    def _save_selected_images(self, destination):
        for image_path in self.selected_images:
            shutil.copy(image_path, destination)
        self.progress.stop()
        self.progress_frame.grid_remove()
        messagebox.showinfo("Success", f"Saved {len(self.selected_images)} images to {destination}")

    def prev_page(self):
        if self.current_page > 0:
            self.current_page -= 1
        else:
            self.current_page = self.total_pages - 1
        self.display_current_page()
        self.update_page_number_entry()

    def next_page(self):
        if self.current_page < self.total_pages - 1:
            self.current_page += 1
        else:
            self.current_page = 0
        self.display_current_page()
        self.update_page_number_entry()

    def update_page_number_entry(self):
        self.page_var.set(str(self.current_page + 1))  # +1 to convert from zero-indexed

    def save_settings(self):
        settings = {
            'gridScaleX': self.gridScaleX,
            'gridScaleY': self.gridScaleY,
            'source': self.source_var.get(),
            'destination': self.destination_var.get(),
            'theme': self.style.theme_use()
        }
        with open(self.settings_file, 'w') as f:
            json.dump(settings, f)

    def load_settings(self):
        try:
            if os.path.exists(self.settings_file):
                with open(self.settings_file, 'r') as f:
                    self.settings = json.load(f)
            else:
                self.settings = {}
        except Exception as e:
            print(f"Error loading settings: {e}")
            self.settings = {}
        if os.path.exists(self.settings_file):
            with open(self.settings_file, 'r') as f:
                self.settings = json.load(f)
            self.style.theme_use(self.settings.get('theme', 'equilux'))
            self.current_theme.set(self.settings.get('theme', 'equilux'))
        else:
            self.settings = {}

    def validate_directories(self):
        if self.source_var.get() and not os.path.isdir(self.source_var.get()):
            messagebox.showerror("Error", "Source directory does not exist. Please select a new source folder.")
            self.browse_directory(self.source_var)
        if self.destination_var.get() and not os.path.isdir(self.destination_var.get()):
            messagebox.showerror("Error", "Destination directory does not exist. Please select a new destination folder.")
            self.browse_directory(self.destination_var)

    def create_layout(self):
        self.background_frame = ttk.Frame(self.master)
        self.background_frame.grid(row=0, column=0, sticky='nsew')
        self.master.grid_rowconfigure(0, weight=1)
        self.master.grid_columnconfigure(0, weight=1)

        self.image_frame = ttk.Frame(self.background_frame)
        self.image_frame.grid(row=1, column=0, columnspan=3, sticky='nsew')
        self.background_frame.grid_rowconfigure(1, weight=1)
        self.background_frame.grid_columnconfigure(1, weight=1)

        self.page_var = StringVar()
        self.page_var.trace('w', self.on_page_number_change)

        self.controls_frame = ttk.Frame(self.background_frame)
        self.controls_frame.grid(row=2, column=1, sticky='ew')
        self.controls_frame.grid_columnconfigure(0, weight=1)
        self.controls_frame.grid_columnconfigure(2, weight=1)

        self.pagination_frame = ttk.Frame(self.controls_frame)
        self.pagination_frame.grid(row=0, column=1)
        self.prev_button = ttk.Button(self.pagination_frame, text="Previous", command=self.prev_page)
        self.prev_button.grid(row=0, column=0, padx=10)
        self.page_entry = ttk.Entry(self.pagination_frame, textvariable=self.page_var, width=5, justify='center')
        self.page_entry.grid(row=0, column=1)
        self.page_label = ttk.Label(self.pagination_frame, text="")
        self.page_label.grid(row=0, column=2, sticky='ew')
        self.next_button = ttk.Button(self.pagination_frame, text="Next", command=self.next_page)
        self.next_button.grid(row=0, column=3, padx=10)

        ttk.Button(self.controls_frame, text="Save Selected Images", command=self.save_selected_images).grid(row=1, column=1, sticky='ew')

        self.progress_frame = ttk.Frame(self.background_frame)
        self.progress_frame.grid(row=3, column=0, columnspan=3, sticky='ew')
        self.progress_label = ttk.Label(self.progress_frame, text="", anchor='w')
        self.progress_label.pack(side='left', padx=5)
        self.progress = ttk.Progressbar(self.progress_frame, mode='indeterminate')
        self.progress.pack(side='left', fill='x', expand=True)
        self.progress_frame.grid_remove()

        self.validate_directories()

        if self.source_var.get() and os.path.isdir(self.source_var.get()):
            self.load_images_from_directory(self.source_var.get())

def main():
    root = ThemedTk(theme="equilux")

    # Configure the styles for images
    style = ttk.Style()
    style.configure('Image.TButton', borderwidth=0, background='#333333')  # No border by default
    style.configure('Highlight.Image.TButton', borderwidth=3, relief='solid', bordercolor='red', background='#ffcccc')  # Red border and light red background for selected images

    app = ImageSelector(root, gridScaleX=3, gridScaleY=3)
    root.mainloop()

if __name__ == "__main__":
    main()