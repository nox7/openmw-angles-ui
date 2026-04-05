import { ComponentFixture, TestBed } from '@angular/core/testing';

import { ForLoopDirectives } from './for-loop-directives';

describe('ForLoopDirectives', () => {
  let component: ForLoopDirectives;
  let fixture: ComponentFixture<ForLoopDirectives>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [ForLoopDirectives]
    })
    .compileComponents();

    fixture = TestBed.createComponent(ForLoopDirectives);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
