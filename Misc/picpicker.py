from tkinter import ttk
import os
import shutil
from tkinter import Tk, Label, Entry, Button, filedialog, Frame, StringVar, messagebox
from PIL import Image, ImageTk
from ttkthemes import ThemedTk

class ImageSelector:
    def __init__(self, master,gridScaleX=3, gridScaleY=3):
        self.master = master
        self.master.title('Image Selector')
        self.master.state('zoomed')  # Maximize the window

        self.style = ttk.Style(master)
        self.style.theme_use('equilux')  # Use the Equilux theme for dark mode
       
        self.gridScaleX = gridScaleX
        self.gridScaleY = gridScaleY
        self.images_per_page = self.gridScaleX * self.gridScaleY
        self.current_page = 0
        self.total_pages = 0
        self.all_image_files = []
        self.selected_images = []

        self.source_var = StringVar()
        self.destination_var = StringVar()
        self.source_var.trace("w", self.on_directory_change)
        self.destination_var.trace("w", self.on_directory_change)

        ttk.Label(master, text="Source:").grid(row=0, column=0, sticky='w')
        self.source_entry = ttk.Entry(master, textvariable=self.source_var, width=50)
        self.source_entry.grid(row=0, column=1, sticky='we')
        ttk.Button(master, text="Browse...", command=lambda: self.browse_directory(self.source_var)).grid(row=0, column=2, sticky='e')
        
        ttk.Label(master, text="Destination:").grid(row=1, column=0, sticky='w')
        self.destination_entry = ttk.Entry(master, textvariable=self.destination_var, width=50)
        self.destination_entry.grid(row=1, column=1, sticky='we')
        ttk.Button(master, text="Browse...", command=lambda: self.browse_directory(self.destination_var)).grid(row=1, column=2, sticky='e')

        self.image_frame = Frame(master)
        self.image_frame.grid(row=2, column=0, columnspan=3, sticky='nsew')
        master.grid_rowconfigure(2, weight=1)
        master.grid_columnconfigure(1, weight=1)

     #    for i in range(3):
     #        self.image_frame.grid_columnconfigure(i, weight=1)
     #        self.image_frame.grid_rowconfigure(i, weight=1)

        self.page_var = StringVar()
        self.page_var.trace('w', self.on_page_number_change)

        self.pagination_frame = ttk.Frame(master)
        self.pagination_frame.grid(row=4, column=0, columnspan=3)
        self.prev_button = ttk.Button(self.pagination_frame, text="Previous", command=self.prev_page)
        self.prev_button.grid(row=0, column=0, padx=10)
        self.page_entry = ttk.Entry(self.pagination_frame, textvariable=self.page_var, width=5, justify='center')
        self.page_entry.grid(row=0, column=1)
        self.page_label = ttk.Label(self.pagination_frame, text="")
        self.page_label.grid(row=0, column=2, sticky='ew')
        self.next_button = ttk.Button(self.pagination_frame, text="Next", command=self.next_page)
        self.next_button.grid(row=0, column=3, padx=10)

        ttk.Button(master, text="Save Selected Images", command=self.save_selected_images).grid(row=5, column=0, columnspan=3, sticky='ew')

    def on_page_number_change(self, *args):
        # Validate and load the page when the page number is entered
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

    def browse_directory(self, variable):
        directory = filedialog.askdirectory()
        if directory:
            variable.set(directory)

    def load_images_from_directory(self, directory):
        self.all_image_files = [f for f in os.listdir(directory) if f.lower().endswith(('.png', '.jpg', '.jpeg', '.gif', '.bmp'))]
        self.total_pages = len(self.all_image_files) // self.images_per_page + (1 if len(self.all_image_files) % self.images_per_page else 0)
        self.current_page = 0
        self.display_current_page()

    def display_current_page(self):
        for widget in self.image_frame.winfo_children():
            widget.destroy()

        start_index = self.current_page * self.images_per_page
        end_index = min(start_index + self.images_per_page, len(self.all_image_files))
        for i, filename in enumerate(self.all_image_files[start_index:end_index]):
            row, column = divmod(i, self.gridScaleX)
            self.display_image(filename, row, column)

          
        self.page_label.config(text=f" of {self.total_pages}")

    def display_image(self, filename, row, column):
        path = os.path.join(self.source_var.get(), filename)
        img = Image.open(path)

        # Calculate the target size dynamically based on the frame size, grid scale, and the number of images
        num_images = len(self.all_image_files) - self.current_page * self.images_per_page
        grid_x = self.gridScaleX if num_images >= self.gridScaleX else num_images
        grid_y = self.gridScaleY if num_images // self.gridScaleX >= self.gridScaleY else num_images // self.gridScaleX + 1
        
        target_size = (self.image_frame.winfo_width() // grid_x - 10,
                       self.image_frame.winfo_height() // grid_y - 10)
        img = img.resize(target_size)
        photo = ImageTk.PhotoImage(img)

        label = ttk.Label(self.image_frame, image=photo, style='Image.TLabel')
        label.image = photo  # Keep a reference!
        label.grid(row=row, column=column, padx=5, pady=5, sticky='nsew')
        label.bind("<Button-1>", lambda e, path=path, label=label: self.toggle_image_selection(path, label))
        label.selected = False

    def toggle_image_selection(self, path, label):
        if label.selected:
            self.selected_images.remove(path)
            label.config(style='Image.TLabel')  # Reset to default style, no border
            label.selected = False
        else:
            self.selected_images.append(path)
            label.config(style='Highlight.Image.TLabel')  # Apply the highlight style with a red border
            label.selected = True

    def save_selected_images(self):
        destination = self.destination_var.get()
        if not os.path.isdir(destination):
            messagebox.showerror("Error", "Destination directory does not exist.")
            return
        for image_path in self.selected_images:
            shutil.copy(image_path, destination)
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
            self.display_current_page()
        else:
            self.current_page = 0
            self.display_current_page()
        self.display_current_page()
        self.update_page_number_entry()

    def update_page_number_entry(self):
        # Update the page entry with the current page number
        self.page_var.set(str(self.current_page + 1))  # +1 to convert from zero-indexed
        
def main():
    root = ThemedTk(theme="equilux")
    
    # Configure the styles for images
    style = ttk.Style()
    style.configure('Image.TLabel', borderwidth=0)  # No border by default
    style.configure('Highlight.Image.TLabel', borderwidth=3, relief='solid', bordercolor='red')  # Red border for selected images

    app = ImageSelector(root,gridScaleX=3, gridScaleY=3)
    root.mainloop()

if __name__ == "__main__":
    main()