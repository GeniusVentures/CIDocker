// GTK header/link probe (PAR-02). gtk_get_major_version is a pure accessor —
// linking it proves gtk3-devel headers+libs resolve without needing an X display.
#include <gtk/gtk.h>
int main(void) { return gtk_get_major_version() == 3 ? 0 : 1; }
