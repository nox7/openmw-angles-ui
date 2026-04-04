import { ComponentFixture, TestBed } from '@angular/core/testing';

import { TextEdit } from './text-edit';

describe('TextEdit', () => {
  let component: TextEdit;
  let fixture: ComponentFixture<TextEdit>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [TextEdit]
    })
    .compileComponents();

    fixture = TestBed.createComponent(TextEdit);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
