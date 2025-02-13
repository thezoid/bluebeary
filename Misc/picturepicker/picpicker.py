from tkinter import ttk
import os
import shutil
import json
from tkinter import Tk, Label, Entry, Button, filedialog, Frame, StringVar, messagebox, Menu, Toplevel, Canvas
from PIL import Image, ImageTk
from ttkthemes import ThemedTk
import threading
from concurrent.futures import ThreadPoolExecutor

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
        action_menu.add_command(label="Settings", command=self.open_settings_dialog)

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
            self.master.after(0, self.display_current_page)
            self.save_settings()
            window.destroy()
        except ValueError:
            messagebox.showerror("Error", "Invalid grid size values.")

    def on_page_number_change(self, *args):
        try:
            page = int(self.page_var.get()) - 1  # Convert to zero-indexed page number
            if 0 <= page < self.total_pages:
                self.current_page = page
                self.master.after(0, self.display_current_page)
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
        try:
            self.all_image_files = [f for f in os.listdir(directory) if f.lower().endswith(('.png', '.jpg', '.jpeg', '.gif', '.bmp'))]
            self.total_pages = len(self.all_image_files) // self.images_per_page + (1 if len(self.all_image_files) % self.images_per_page else 0)
            self.current_page = 0
            self.master.after(0, self.display_current_page)
        except Exception as e:
            self.master.after(0, lambda: messagebox.showerror("Error", f"Failed to load images: {e}"))
        finally:
            self.master.after(0, self.progress.stop)
            self.master.after(0, self.progress_frame.grid_remove)

    def display_current_page(self):
        for widget in self.image_frame.winfo_children():
            widget.destroy()

        start_index = self.current_page * self.images_per_page
        end_index = min(start_index + self.images_per_page, len(self.all_image_files))
        filenames = self.all_image_files[start_index:end_index]

        threading.Thread(target=self._load_and_display_images, args=(filenames,)).start()

    def _load_and_display_images(self, filenames):
        with ThreadPoolExecutor() as executor:
            futures = [executor.submit(self.load_image, filename) for filename in filenames]
            for i, future in enumerate(futures):
                row, column = divmod(i, self.gridScaleX)
                self.master.after(0, self.display_image, future.result(), row, column)

        self.master.after(0, lambda: self.page_label.config(text=f" of {self.total_pages}"))

        # Pre-cache pages 2 before and 2 after the current page
        threading.Thread(target=self.pre_cache_pages).start()

    def load_image(self, filename):
        path = os.path.join(self.source_var.get(), filename)
        img = Image.open(path)
        target_width = max(self.image_frame.winfo_width() // self.gridScaleX - 10, 1)
        target_height = max(self.image_frame.winfo_height() // self.gridScaleY - 10, 1)
        img.thumbnail((target_width, target_height))
        return ImageTk.PhotoImage(img)

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
        for filename in self.all_image_files[start_index:end_index]:
            self.load_image(filename)

    def display_image(self, photo, row, column):
        button = ttk.Button(self.image_frame, image=photo, style='Image.TButton')
        button.image = photo  # Keep a reference!
        button.grid(row=row, column=column, padx=5, pady=5, sticky='nsew')
        button.bind("<Button-1>", lambda e, button=button, filename=photo: self.toggle_image_selection(button, filename))
        button.selected = os.path.join(self.source_var.get(), photo) in self.selected_images

        if button.selected:
            button.config(style='Highlight.Image.TButton')

        # Center the grid horizontally
        self.image_frame.grid_columnconfigure(column, weight=1)

    def toggle_image_selection(self, button, filename):
        file_path = os.path.join(self.source_var.get(), filename)
        if button.selected:
            self.selected_images.remove(file_path)
            button.config(style='Image.TButton')  # Reset to default style
            button.selected = False
        else:
            self.selected_images.append(file_path)
            button.config(style='Highlight.Image.TButton')  # Apply the highlight style
            button.selected = True
        self.update_status_bar()

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
        try:
            for image_path in self.selected_images:
                shutil.copy(image_path, destination)
            self.master.after(0, lambda: messagebox.showinfo("Success", f"Saved {len(self.selected_images)} images to {destination}"))
        except Exception as e:
            self.master.after(0, lambda e=e: messagebox.showerror("Error", f"Failed to save images: {e}"))
        finally:
            self.progress.stop()
            self.progress_frame.grid_remove()

    def prev_page(self):
        if self.current_page > 0:
            self.current_page -= 1
        else:
            self.current_page = self.total_pages - 1
        self.master.after(0, self.display_current_page)
        self.update_page_number_entry()

    def next_page(self):
        if self.current_page < self.total_pages - 1:
            self.current_page += 1
        else:
            self.current_page = 0
        self.master.after(0, self.display_current_page)
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
        try:
            with open(self.settings_file, 'w') as f:
                json.dump(settings, f)
        except Exception as e:
            messagebox.showerror("Error", f"Failed to save settings: {e}")

    def load_settings(self):
        try:
            if os.path.exists(self.settings_file):
                with open(self.settings_file, 'r') as f:
                    self.settings = json.load(f)
            else:
                self.settings = {}
        except Exception as e:
            messagebox.showerror("Error", f"Failed to load settings: {e}")
            self.settings = {}
        self.style.theme_use(self.settings.get('theme', 'equilux'))
        self.current_theme.set(self.settings.get('theme', 'equilux'))

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

        self.status_bar = ttk.Label(self.background_frame, text="0 images selected", anchor='w')
        self.status_bar.grid(row=4, column=0, columnspan=3, sticky='ew')

        self.validate_directories()

        if self.source_var.get() and os.path.isdir(self.source_var.get()):
            self.load_images_from_directory(self.source_var.get())

    def update_status_bar(self):
        self.status_bar.config(text=f"{len(self.selected_images)} images selected")

    def open_settings_dialog(self):
        settings_window = Toplevel(self.master)
        settings_window.title("Settings")

        ttk.Label(settings_window, text="Theme:").grid(row=0, column=0, padx=10, pady=10)
        theme_menu = ttk.OptionMenu(settings_window, self.current_theme, self.current_theme.get(), *self.themes)
        theme_menu.grid(row=0, column=1, padx=10, pady=10)

        ttk.Label(settings_window, text="Grid Size X:").grid(row=1, column=0, padx=10, pady=10)
        grid_x_entry = ttk.Entry(settings_window)
        grid_x_entry.insert(0, str(self.gridScaleX))
        grid_x_entry.grid(row=1, column=1, padx=10, pady=10)

        ttk.Label(settings_window, text="Grid Size Y:").grid(row=2, column=0, padx=10, pady=10)
        grid_y_entry = ttk.Entry(settings_window)
        grid_y_entry.insert(0, str(self.gridScaleY))
        grid_y_entry.grid(row=2, column=1, padx=10, pady=10)

        ttk.Button(settings_window, text="Save", command=lambda: self.save_settings_dialog(grid_x_entry.get(), grid_y_entry.get(), settings_window)).grid(row=3, column=0, columnspan=2, pady=10)

    def save_settings_dialog(self, x, y, window):
        try:
            self.gridScaleX = int(x)
            self.gridScaleY = int(y)
            self.images_per_page = self.gridScaleX * self.gridScaleY
            self.total_pages = len(self.all_image_files) // self.images_per_page + (1 if len(self.all_image_files) % self.images_per_page else 0)
            self.current_page = 0
            self.master.after(0, self.display_current_page)
            self.save_settings()
            window.destroy()
        except ValueError:
            messagebox.showerror("Error", "Invalid grid size values.")

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