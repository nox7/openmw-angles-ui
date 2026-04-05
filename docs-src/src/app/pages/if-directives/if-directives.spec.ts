import { ComponentFixture, TestBed } from '@angular/core/testing';

import { IfDirectives } from './if-directives';

describe('IfDirectives', () => {
  let component: IfDirectives;
  let fixture: ComponentFixture<IfDirectives>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [IfDirectives]
    })
    .compileComponents();

    fixture = TestBed.createComponent(IfDirectives);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
