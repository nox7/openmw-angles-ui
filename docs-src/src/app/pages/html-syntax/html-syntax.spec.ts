import { ComponentFixture, TestBed } from '@angular/core/testing';

import { HtmlSyntax } from './html-syntax';

describe('HtmlSyntax', () => {
  let component: HtmlSyntax;
  let fixture: ComponentFixture<HtmlSyntax>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [HtmlSyntax]
    })
    .compileComponents();

    fixture = TestBed.createComponent(HtmlSyntax);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
