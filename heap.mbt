///|
priv struct MinHeap {
  items : Array[(Double, String)]
}

///|
fn heap_less(left : (Double, String), right : (Double, String)) -> Bool {
  if left.0 != right.0 {
    left.0 < right.0
  } else {
    left.1 < right.1
  }
}

///|
fn MinHeap::push(self : MinHeap, entry : (Double, String)) -> Unit {
  self.items.push(entry)
  let mut index = self.items.length() - 1
  while index > 0 {
    let parent = (index - 1) / 2
    if !heap_less(self.items[index], self.items[parent]) {
      break
    }
    let swapped = self.items[index]
    self.items[index] = self.items[parent]
    self.items[parent] = swapped
    index = parent
  }
}

///|
fn MinHeap::pop(self : MinHeap) -> (Double, String)? {
  if self.items.is_empty() {
    return None
  }
  let top = self.items[0]
  let last = self.items.pop().unwrap()
  if !self.items.is_empty() {
    self.items[0] = last
    let mut index = 0
    while true {
      let left = index * 2 + 1
      let right = index * 2 + 2
      let mut smallest = index
      if left < self.items.length() &&
        heap_less(self.items[left], self.items[smallest]) {
        smallest = left
      }
      if right < self.items.length() &&
        heap_less(self.items[right], self.items[smallest]) {
        smallest = right
      }
      if smallest == index {
        break
      }
      let swapped = self.items[index]
      self.items[index] = self.items[smallest]
      self.items[smallest] = swapped
      index = smallest
    }
  }
  Some(top)
}
