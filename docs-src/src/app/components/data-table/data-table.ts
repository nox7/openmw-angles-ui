import { afterNextRender, Component, ElementRef, inject, input, ViewEncapsulation } from '@angular/core';

@Component({
  selector: 'app-data-table',
  imports: [],
  templateUrl: './data-table.html',
  styleUrl: './data-table.scss',
  encapsulation: ViewEncapsulation.None,
})
export class DataTable {
  private readonly Element = inject(ElementRef);
  /**
   * An array of percentage values that equal the number of columns in the table.
   */
  public ColumnWidthPercentages = input.required<string[]>();

  public constructor() {
    afterNextRender({
      mixedReadWrite: () => {
        const element = this.Element.nativeElement as HTMLElement;
        const headers = element.querySelectorAll<HTMLElement>('app-dt-header');
        const rows = element.querySelectorAll<HTMLElement>('app-dt-row');
        for (const [index, header] of headers.entries()) {
          header.style.maxWidth = this.ColumnWidthPercentages()[index];
        }
        for (const [index, row] of rows.entries()) {
          const cells = row.querySelectorAll<HTMLElement>('app-dt-cell');
          for (const [cellIndex, cell] of cells.entries()) {
            cell.style.maxWidth = this.ColumnWidthPercentages()[cellIndex];
          }
        }
      }
    });
  }
}
